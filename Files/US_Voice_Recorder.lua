-- ==========================================
-- US Voice Recorder (Lua 5.3+ for Jieshuo)
-- Final Clean Edition (Android 16 Share Fix + Auto Cleanup)
-- Creator: Mohammad Usman
-- WhatsApp: 03261421100
-- ==========================================

require "import"
import "android.app.AlertDialog"
import "android.content.Context"
import "android.content.Intent"
import "android.content.ClipData"
import "android.content.ClipboardManager"
import "android.content.ContentValues"
import "android.media.MediaRecorder"
import "android.media.MediaPlayer"
import "android.media.ToneGenerator"
import "android.media.AudioManager"
import "android.media.audiofx.LoudnessEnhancer"
import "android.net.Uri"
import "android.os.Build"
import "android.os.Handler"
import "android.os.Looper"
import "android.os.StrictMode"
import "android.os.VibrationEffect"
import "android.provider.MediaStore"
import "android.view.Gravity"
import "android.view.WindowManager"
import "android.widget.Button"
import "android.widget.LinearLayout"
import "android.widget.ScrollView"
import "android.widget.TextView"
import "android.widget.Toast"
import "android.widget.EditText"
import "java.io.File"
import "java.io.FileInputStream"

local APP_NAME = "US Voice Recorder"
local CREATOR_NAME = "Mohammad Usman"
local WHATSAPP_NUM = "03261421100"
local WHATSAPP_INTL = "923261421100"

local APP_DESCRIPTION = [[US Voice Recorder Jieshuo Screen Reader ke liye banayi gayi ek tez aur aasaan Studio HD voice recording extension hai.

Iski madad se aap sirf ek gesture se apni aur speaker ki awaaz bilkul saaf aur clear Studio HD quality mein record kar sakte hain. Doosri baar gesture chalane par recording ruk jati hai aur screen ke niche ek accessible menu khul jata hai, jahan se aap recording sun sakte hain, aage-piche kar sakte hain, MP3 format mein save kar sakte hain, seedha WhatsApp par share kar sakte hain, ya delete kar sakte hain.

Settings mein ja kar aap vibration, start/stop tone, TTS announcement, audio quality, mic source, aur skip time apni marzi se tabdeel kar sakte hain.]]

-- Default Settings (Standard MIC for Zero Speaker Hiss)
local CONFIG_PATH = "/sdcard/US_Voice_Recorder/settings.conf"
local settings = {
  vibrate = true,
  tone = true,
  tts = true,
  quality = "Studio HD",  -- HD (192k), Studio HD (256k), Max Ultra (320k)
  micSource = "Standard", -- Standard (Zero Hiss), Camcorder (Loud), Unprocessed
  skipTime = 5,           -- 5, 10, 15 seconds
  saveFolder = "/sdcard/US_Voice_Recorder"
}

-- Global State
_G.US_REC_STATE = _G.US_REC_STATE or {
  isRecording = false,
  recorder = nil,
  tempFile = nil,
  isSaved = false,
  startTime = 0,
  durationSec = 0
}
local state = _G.US_REC_STATE

-- Helper: Ensure Folder Exists
local function ensureDir(path)
  local dir = File(path)
  if not dir.exists() then
    dir.mkdirs()
  end
end

-- Load & Save Settings
local function saveSettings()
  ensureDir("/sdcard/US_Voice_Recorder")
  local f = io.open(CONFIG_PATH, "w")
  if f then
    f:write("vibrate=" .. tostring(settings.vibrate) .. "\n")
    f:write("tone=" .. tostring(settings.tone) .. "\n")
    f:write("tts=" .. tostring(settings.tts) .. "\n")
    f:write("quality=" .. tostring(settings.quality) .. "\n")
    f:write("micSource=" .. tostring(settings.micSource) .. "\n")
    f:write("skipTime=" .. tostring(settings.skipTime) .. "\n")
    f:write("saveFolder=" .. tostring(settings.saveFolder) .. "\n")
    f:write("v3=true\n")
    f:close()
  end
end

local function loadSettings()
  local f = io.open(CONFIG_PATH, "r")
  local hasV3 = false
  if f then
    for line in f:lines() do
      local k, v = line:match("^(.-)=(.*)$")
      if k and v then
        if k == "vibrate" then settings.vibrate = (v == "true")
        elseif k == "tone" then settings.tone = (v == "true")
        elseif k == "tts" then settings.tts = (v == "true")
        elseif k == "quality" then settings.quality = v
        elseif k == "micSource" then settings.micSource = v
        elseif k == "skipTime" then settings.skipTime = tonumber(v) or 5
        elseif k == "saveFolder" then settings.saveFolder = v
        elseif k == "v3" then hasV3 = (v == "true")
        end
      end
    end
    f:close()
  end
  if not hasV3 then
    settings.micSource = "Standard"
    saveSettings()
  end
end

loadSettings()

-- Helper: TTS Speak (English)
local function speak(text)
  if not settings.tts then return end
  pcall(function()
    if service and service.speak then
      service.speak(text)
    elseif service and service.say then
      service.say(text)
    end
  end)
end

-- Helper: Toast (English)
local function showToast(msg)
  pcall(function()
    Toast.makeText(service, msg, Toast.LENGTH_SHORT).show()
  end)
end

-- Helper: Vibrate
local function doVibrate(ms)
  if not settings.vibrate then return end
  pcall(function()
    local vib = service.getSystemService(Context.VIBRATOR_SERVICE)
    if vib then
      if Build.VERSION.SDK_INT >= 26 then
        vib.vibrate(VibrationEffect.createOneShot(ms or 80, VibrationEffect.DEFAULT_AMPLITUDE))
      else
        vib.vibrate(ms or 80)
      end
    end
  end)
end

-- Helper: Soft Modern Chime Tone (Start / Stop)
local function playTone(isStart)
  if not settings.tone then return end
  pcall(function()
    local tg = ToneGenerator(AudioManager.STREAM_MUSIC, 75)
    if isStart then
      tg.startTone(ToneGenerator.TONE_PROP_PROMPT, 180)
    else
      tg.startTone(ToneGenerator.TONE_PROP_ACK, 180)
    end
    Handler(Looper.getMainLooper()).postDelayed(Runnable{
      run = function()
        pcall(function() tg.release() end)
      end
    }, 300)
  end)
end

-- Helper: Format MM:SS
local function formatTime(sec)
  local m = math.floor(sec / 60)
  local s = math.floor(sec % 60)
  return string.format("%02d:%02d", m, s)
end

-- Helper: Delete Unsaved Temp File
local function cleanupTempFile()
  if not state.isSaved and state.tempFile then
    pcall(function()
      local f = File(state.tempFile)
      if f.exists() then f.delete() end
    end)
    state.tempFile = nil
  end
end

-- Helper: Create Shareable content:// URI via MediaStore (Android 10 - 16 Safe)
local function getShareUri(filePath)
  local srcFile = File(filePath)
  if not srcFile.exists() then return nil end

  if Build.VERSION.SDK_INT >= 29 then
    local ok, contentUri = pcall(function()
      local resolver = service.getContentResolver()
      local values = ContentValues()
      local shareName = "US_Rec_" .. os.date("%Y%m%d_%H%M%S") .. ".mp3"
      values.put(MediaStore.MediaColumns.DISPLAY_NAME, shareName)
      values.put(MediaStore.MediaColumns.MIME_TYPE, "audio/mpeg")
      values.put(MediaStore.MediaColumns.RELATIVE_PATH, "Music/US_Voice_Recorder")

      local uri = resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
      if uri then
        local outStream = resolver.openOutputStream(uri)
        local inStream = FileInputStream(srcFile)
        local buf = luajava.newArray(luajava.bindClass("java.lang.Byte").TYPE, 8192)
        while true do
          local len = inStream.read(buf)
          if len == -1 then break end
          outStream.write(buf, 0, len)
        end
        inStream.close()
        outStream.flush()
        outStream.close()
      end
      return uri
    end)
    if ok and contentUri then
      return contentUri
    end
  end

  -- Fallback for Android 9 and below
  local builder = StrictMode.VmPolicy.Builder()
  StrictMode.setVmPolicy(builder.build())
  return Uri.fromFile(srcFile)
end

-- Helper: Show Overlay Dialog (Bottom Aligned)
local function showOverlayDialog(dialog, atBottom)
  pcall(function()
    local win = dialog.getWindow()
    if win then
      if Build.VERSION.SDK_INT >= 26 then
        win.setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
      else
        win.setType(WindowManager.LayoutParams.TYPE_SYSTEM_ALERT)
      end
      if atBottom then
        win.setGravity(Gravity.BOTTOM)
        local lp = win.getAttributes()
        lp.width = WindowManager.LayoutParams.MATCH_PARENT
        win.setAttributes(lp)
      end
    end
  end)
  dialog.show()
end

-- Helper: Create Styled Button
local function makeBtn(text, weight, onClick)
  local btn = Button(service)
  btn.setText(text)
  btn.setAllCaps(false)
  btn.setTextSize(13)
  if weight then
    local lp = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, weight)
    lp.setMargins(4, 4, 4, 4)
    btn.setLayoutParams(lp)
  end
  btn.setOnClickListener(luajava.createProxy("android.view.View$OnClickListener", {
    onClick = function(v)
      pcall(onClick, v)
    end
  }))
  return btn
end

-- Forward Declarations
local showMainMenu
local showSettingsMenu
local showAboutMenu
local showDescriptionMenu

-- ==========================================
-- 1. RECORDING LOGIC
-- ==========================================
local function prepareAndStartRecorder(useFallbackMic)
  local rec = MediaRecorder()

  if useFallbackMic then
    rec.setAudioSource(MediaRecorder.AudioSource.MIC)
  elseif settings.micSource == "Camcorder" then
    rec.setAudioSource(MediaRecorder.AudioSource.CAMCORDER)
  elseif settings.micSource == "Unprocessed" and Build.VERSION.SDK_INT >= 24 then
    rec.setAudioSource(MediaRecorder.AudioSource.UNPROCESSED)
  else
    rec.setAudioSource(MediaRecorder.AudioSource.MIC)
  end

  rec.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
  rec.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
  rec.setAudioChannels(1)
  rec.setAudioSamplingRate(48000)

  if settings.quality == "HD" then
    rec.setAudioEncodingBitRate(192000)
  elseif settings.quality == "Max Ultra" then
    rec.setAudioEncodingBitRate(320000)
  else
    rec.setAudioEncodingBitRate(256000)
  end

  rec.setOutputFile(state.tempFile)
  rec.prepare()
  rec.start()
  return rec
end

local function startRecording()
  ensureDir(settings.saveFolder)
  state.tempFile = settings.saveFolder .. "/temp_recording.mp3"
  state.isSaved = false

  doVibrate(80)
  speak("Recording started")

  Handler(Looper.getMainLooper()).postDelayed(Runnable{
    run = function()
      playTone(true)
    end
  }, 350)

  Handler(Looper.getMainLooper()).postDelayed(Runnable{
    run = function()
      local ok, recOrErr = pcall(prepareAndStartRecorder, false)
      if not ok then
        ok, recOrErr = pcall(prepareAndStartRecorder, true)
      end

      if ok and recOrErr then
        state.recorder = recOrErr
        state.isRecording = true
        state.startTime = os.time()
      else
        state.isRecording = false
        showToast("Recording error: " .. tostring(recOrErr))
        speak("Failed to start recording")
      end
    end
  }, 650)
end

-- Exact Stop Sequence: Stop -> Tone -> TTS ("Recording stopped") -> Menu
local function stopRecording()
  pcall(function()
    if state.recorder then
      state.recorder.stop()
      state.recorder.release()
      state.recorder = nil
    end
  end)

  state.isRecording = false
  state.durationSec = math.max(1, os.time() - state.startTime)

  doVibrate(60)
  playTone(false)

  Handler(Looper.getMainLooper()).postDelayed(Runnable{
    run = function()
      speak("Recording stopped")
    end
  }, 220)

  Handler(Looper.getMainLooper()).postDelayed(Runnable{
    run = function()
      showMainMenu()
    end
  }, 1050)
end

-- ==========================================
-- 2. APP DESCRIPTION MENU
-- ==========================================
showDescriptionMenu = function()
  local root = LinearLayout(service)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setPadding(30, 30, 30, 30)

  local title = TextView(service)
  title.setText(APP_NAME .. " - Description")
  title.setTextSize(18)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, 0, 0, 20)
  root.addView(title)

  local scroll = ScrollView(service)
  local descTxt = TextView(service)
  descTxt.setText(APP_DESCRIPTION)
  descTxt.setTextSize(15)
  scroll.addView(descTxt)
  root.addView(scroll)

  local dlg = AlertDialog.Builder(service).setView(root).create()

  local backBtn = makeBtn("Back", nil, function()
    dlg.dismiss()
    showSettingsMenu()
  end)
  root.addView(backBtn)

  showOverlayDialog(dlg, true)
end

-- ==========================================
-- 3. ABOUT & SUPPORT MENU
-- ==========================================
showAboutMenu = function()
  local root = LinearLayout(service)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setPadding(30, 30, 30, 30)

  local title = TextView(service)
  title.setText("About & Support")
  title.setTextSize(18)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, 0, 0, 20)
  root.addView(title)

  local info = TextView(service)
  info.setText(
    "Extension Name: " .. APP_NAME .. "\n" ..
    "Creator: " .. CREATOR_NAME .. "\n" ..
    "WhatsApp: " .. WHATSAPP_NUM
  )
  info.setTextSize(15)
  info.setPadding(0, 0, 0, 20)
  root.addView(info)

  local dlg = AlertDialog.Builder(service).setView(root).create()

  local copyBtn = makeBtn("Copy Number", nil, function()
    pcall(function()
      local cm = service.getSystemService(Context.CLIPBOARD_SERVICE)
      local clip = ClipData.newPlainText("WhatsApp", WHATSAPP_NUM)
      cm.setPrimaryClip(clip)
      showToast("Number copied: " .. WHATSAPP_NUM)
      speak("Number copied")
    end)
  end)
  root.addView(copyBtn)

  local waBtn = makeBtn("Contact on WhatsApp", nil, function()
    dlg.dismiss()
    pcall(function()
      local intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/" .. WHATSAPP_INTL))
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      service.startActivity(intent)
    end)
  end)
  root.addView(waBtn)

  local backBtn = makeBtn("Back", nil, function()
    dlg.dismiss()
    showSettingsMenu()
  end)
  root.addView(backBtn)

  showOverlayDialog(dlg, true)
end

-- ==========================================
-- 4. SETTINGS MENU
-- ==========================================
showSettingsMenu = function()
  local root = LinearLayout(service)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setPadding(25, 25, 25, 25)

  local title = TextView(service)
  title.setText("Settings - " .. APP_NAME)
  title.setTextSize(18)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, 0, 0, 15)
  root.addView(title)

  local scroll = ScrollView(service)
  local list = LinearLayout(service)
  list.setOrientation(LinearLayout.VERTICAL)
  scroll.addView(list)
  root.addView(scroll)

  local dlg = AlertDialog.Builder(service).setView(root).create()

  -- 1. Vibration
  local vibBtn
  vibBtn = makeBtn("Vibration: " .. (settings.vibrate and "On" or "Off"), nil, function()
    settings.vibrate = not settings.vibrate
    saveSettings()
    vibBtn.setText("Vibration: " .. (settings.vibrate and "On" or "Off"))
    speak("Vibration " .. (settings.vibrate and "on" or "off"))
  end)
  list.addView(vibBtn)

  -- 2. Start/Stop Tone
  local toneBtn
  toneBtn = makeBtn("Start/Stop Tone: " .. (settings.tone and "On" or "Off"), nil, function()
    settings.tone = not settings.tone
    saveSettings()
    toneBtn.setText("Start/Stop Tone: " .. (settings.tone and "On" or "Off"))
    speak("Tone " .. (settings.tone and "on" or "off"))
  end)
  list.addView(toneBtn)

  -- 3. TTS Announcement
  local ttsBtn
  ttsBtn = makeBtn("TTS Announcement: " .. (settings.tts and "On" or "Off"), nil, function()
    settings.tts = not settings.tts
    saveSettings()
    ttsBtn.setText("TTS Announcement: " .. (settings.tts and "On" or "Off"))
  end)
  list.addView(ttsBtn)

  -- 4. Audio Quality
  local qualBtn
  qualBtn = makeBtn("Audio Quality: " .. settings.quality, nil, function()
    if settings.quality == "HD" then settings.quality = "Studio HD"
    elseif settings.quality == "Studio HD" then settings.quality = "Max Ultra"
    else settings.quality = "HD" end
    saveSettings()
    qualBtn.setText("Audio Quality: " .. settings.quality)
    speak("Audio quality " .. settings.quality)
  end)
  list.addView(qualBtn)

  -- 5. Mic Source
  local micBtn
  micBtn = makeBtn("Mic Source: " .. settings.micSource, nil, function()
    if settings.micSource == "Standard" then settings.micSource = "Camcorder"
    elseif settings.micSource == "Camcorder" then settings.micSource = "Unprocessed"
    else settings.micSource = "Standard" end
    saveSettings()
    micBtn.setText("Mic Source: " .. settings.micSource)
    speak("Mic source " .. settings.micSource)
  end)
  list.addView(micBtn)

  -- 6. Skip Time
  local skipBtn
  skipBtn = makeBtn("Skip Time: " .. settings.skipTime .. " sec", nil, function()
    if settings.skipTime == 5 then settings.skipTime = 10
    elseif settings.skipTime == 10 then settings.skipTime = 15
    else settings.skipTime = 5 end
    saveSettings()
    skipBtn.setText("Skip Time: " .. settings.skipTime .. " sec")
    speak("Skip time " .. settings.skipTime .. " seconds")
  end)
  list.addView(skipBtn)

  -- 7. Save Folder
  local folderBtn = makeBtn("Save Folder: " .. settings.saveFolder, nil, function()
    local input = EditText(service)
    input.setText(settings.saveFolder)
    local fDlg = AlertDialog.Builder(service)
      .setTitle("Save Folder Path")
      .setView(input)
      .setPositiveButton("Save", function()
        local newPath = tostring(input.getText()):gsub("/$", "")
        if newPath ~= "" then
          settings.saveFolder = newPath
          ensureDir(settings.saveFolder)
          saveSettings()
          speak("Save folder updated")
          dlg.dismiss()
          showSettingsMenu()
        end
      end)
      .setNegativeButton("Cancel", nil)
      .create()
    showOverlayDialog(fDlg, false)
  end)
  list.addView(folderBtn)

  -- 8. App Description
  local descBtn = makeBtn("App Description", nil, function()
    dlg.dismiss()
    showDescriptionMenu()
  end)
  list.addView(descBtn)

  -- 9. About & Support
  local aboutBtn = makeBtn("About & Support", nil, function()
    dlg.dismiss()
    showAboutMenu()
  end)
  list.addView(aboutBtn)

  -- 10. Back
  local backBtn = makeBtn("Back", nil, function()
    dlg.dismiss()
    showMainMenu()
  end)
  list.addView(backBtn)

  showOverlayDialog(dlg, true)
end

-- ==========================================
-- 5. MAIN MENU (Bottom, 4 Buttons Per Row)
-- ==========================================
showMainMenu = function()
  local player = nil
  local enhancer = nil
  local isPlaying = false
  local navigatingToSettings = false

  local function releasePlayer()
    pcall(function()
      if enhancer then
        enhancer.release()
        enhancer = nil
      end
      if player then
        if player.isPlaying() then player.stop() end
        player.release()
        player = nil
      end
    end)
    isPlaying = false
  end

  local root = LinearLayout(service)
  root.setOrientation(LinearLayout.VERTICAL)
  root.setPadding(20, 25, 20, 25)

  -- Top Center Title
  local title = TextView(service)
  title.setText(APP_NAME)
  title.setTextSize(19)
  title.setGravity(Gravity.CENTER)
  root.addView(title)

  -- Duration Display
  local durTxt = TextView(service)
  durTxt.setText("Duration: " .. formatTime(state.durationSec))
  durTxt.setTextSize(14)
  durTxt.setGravity(Gravity.CENTER)
  durTxt.setPadding(0, 6, 0, 18)
  root.addView(durTxt)

  local dlg = AlertDialog.Builder(service).setView(root).create()
  dlg.setOnDismissListener(luajava.createProxy("android.content.DialogInterface$OnDismissListener", {
    onDismiss = function()
      releasePlayer()
      -- Auto-delete unsaved temp recording when closed
      if not navigatingToSettings then
        cleanupTempFile()
      end
    end
  }))

  -- ROW 1: Previous | Play/Pause | Next | Save
  local row1 = LinearLayout(service)
  row1.setOrientation(LinearLayout.HORIZONTAL)

  local playBtn

  local prevBtn = makeBtn("Previous", 1, function()
    if player then
      local pos = math.max(0, player.getCurrentPosition() - (settings.skipTime * 1000))
      player.seekTo(pos)
    end
  end)

  playBtn = makeBtn("Play", 1, function()
    if not state.tempFile or not File(state.tempFile).exists() then
      showToast("No recording found")
      speak("No recording found")
      return
    end
    if not player then
      player = MediaPlayer()
      player.setDataSource(state.tempFile)
      player.prepare()
      pcall(function()
        if Build.VERSION.SDK_INT >= 19 then
          enhancer = LoudnessEnhancer(player.getAudioSessionId())
          enhancer.setTargetGain(600)
          enhancer.setEnabled(true)
        end
      end)
      player.setOnCompletionListener(luajava.createProxy("android.media.MediaPlayer$OnCompletionListener", {
        onCompletion = function()
          isPlaying = false
          playBtn.setText("Play")
        end
      }))
    end
    if isPlaying then
      player.pause()
      isPlaying = false
      playBtn.setText("Play")
    else
      player.start()
      isPlaying = true
      playBtn.setText("Pause")
    end
  end)

  local nextBtn = makeBtn("Next", 1, function()
    if player then
      local pos = math.min(player.getDuration(), player.getCurrentPosition() + (settings.skipTime * 1000))
      player.seekTo(pos)
    end
  end)

  local saveBtn = makeBtn("Save", 1, function()
    releasePlayer()
    if not state.tempFile or not File(state.tempFile).exists() then
      showToast("No recording to save")
      speak("No recording to save")
      return
    end
    if state.isSaved then
      showToast("Already saved")
      speak("Already saved")
      return
    end
    ensureDir(settings.saveFolder)
    local finalName = "US_Rec_" .. os.date("%Y%m%d_%H%M%S") .. ".mp3"
    local finalPath = settings.saveFolder .. "/" .. finalName
    local ok = File(state.tempFile).renameTo(File(finalPath))
    if ok then
      state.tempFile = finalPath
      state.isSaved = true
      showToast("Saved: " .. finalName)
      speak("Recording saved")
    else
      showToast("Failed to save recording")
      speak("Failed to save recording")
    end
  end)

  row1.addView(prevBtn)
  row1.addView(playBtn)
  row1.addView(nextBtn)
  row1.addView(saveBtn)
  root.addView(row1)

  -- ROW 2: Share | Delete | Settings | Close
  local row2 = LinearLayout(service)
  row2.setOrientation(LinearLayout.HORIZONTAL)

  local shareBtn = makeBtn("Share", 1, function()
    releasePlayer()
    if not state.tempFile or not File(state.tempFile).exists() then
      showToast("No recording to share")
      speak("No recording to share")
      return
    end
    local shareUri = getShareUri(state.tempFile)
    if not shareUri then
      showToast("Failed to prepare file for sharing")
      speak("Failed to share recording")
      return
    end
    dlg.dismiss()
    pcall(function()
      local intent = Intent(Intent.ACTION_SEND)
      intent.setType("audio/mpeg")
      intent.putExtra(Intent.EXTRA_STREAM, shareUri)
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

      local chooser = Intent.createChooser(intent, "Share Recording")
      chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      service.startActivity(chooser)
    end)
  end)

  local deleteBtn = makeBtn("Delete", 1, function()
    local cDlg = AlertDialog.Builder(service)
      .setTitle("Delete Confirmation")
      .setMessage("Are you sure you want to delete this recording?")
      .setPositiveButton("Delete", function()
        releasePlayer()
        if state.tempFile then
          File(state.tempFile).delete()
          state.tempFile = nil
          state.isSaved = false
        end
        showToast("Recording deleted")
        speak("Recording deleted")
        dlg.dismiss()
      end)
      .setNegativeButton("Cancel", nil)
      .create()
    showOverlayDialog(cDlg, false)
  end)

  local settingsBtn = makeBtn("Settings", 1, function()
    navigatingToSettings = true
    releasePlayer()
    dlg.dismiss()
    showSettingsMenu()
  end)

  local closeBtn = makeBtn("Close", 1, function()
    releasePlayer()
    dlg.dismiss()
  end)

  row2.addView(shareBtn)
  row2.addView(deleteBtn)
  row2.addView(settingsBtn)
  row2.addView(closeBtn)
  root.addView(row2)

  showOverlayDialog(dlg, true)
end

-- ==========================================
-- ENTRY POINT (Toggle Start / Stop)
-- ==========================================
if state.isRecording then
  stopRecording()
else
  startRecording()
end
