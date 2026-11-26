-- ============================================================
-- Extension Name : Gemini Audio & Broadcast Studio (Launch v4)
-- Created By     : Mohammed Usman (WhatsApp: 03261421100)
-- Platform       : Jieshuo Screen Reader (Lua 5.3+)
-- Features       : Clean Button UI (No Extra Headings), 1-6 Speakers,
--                  Voice Preview Dialog (3-5s Cached + DONE Button),
--                  90 Languages (Scrollable List, #1 Urdu, #2 English),
--                  29 Strict Single Styles, 25 Strict Broadcast Moods,
--                  Part-to-Part Tone Lock (2-3 Lines Context),
--                  5 API Keys Auto-Failover, Focus Lock & Smart EXIT
-- ============================================================
-- PART 1 OF 3: Imports, State, 90 Languages, Strict Moods, 5-Key Rotation,
--              Focus Lock, Voice Sample Preview (3-5s), HTTP & WAV Engine
-- ============================================================

require "import"
import "com.androlua.Http"
import "cjson"
import "com.androlua.LuaDialog"
import "android.widget.*"
import "android.view.*"
import "android.content.Context"
import "android.content.Intent"
import "android.content.ContentValues"
import "android.content.ClipboardManager"
import "android.content.ClipData"
import "android.net.Uri"
import "android.media.MediaPlayer"
import "android.util.Base64"
import "android.os.*"
import "android.graphics.Typeface"
import "android.graphics.Color"
import "java.io.*"
import "java.lang.Runnable"
import "java.util.HashMap"
import "android.text.InputType"
import "android.view.accessibility.AccessibilityEvent"

local context = activity or service
local mainHandler = Handler(Looper.getMainLooper())

-- Network Timeouts
pcall(function() Http.setConnTimeout(60000) end)
pcall(function() Http.setReadTimeout(240000) end)
pcall(function() Http.setTimeout(240000) end)

-- Global Background State (Survives EXIT when job is running)
if not _G.GEMINI_ABS_V4 then
    _G.GEMINI_ABS_V4 = {
        jobId = 0,
        isGenerating = false,
        isWritingScript = false,
        percent = 0,
        statusText = "Status: Ready",
        generatedAudioPath = nil,
        currentDurationStr = "",
        mediaPlayer = nil,
        previewPlayer = nil,
        isPlaying = false,
        ui = nil
    }
end
local S = _G.GEMINI_ABS_V4

-- Unified Module Table
local M = {}

M.APP_TITLE = "Gemini Audio & Broadcast Studio"
M.CREATOR_NAME = "Mohammed Usman"
M.WHATSAPP_LOCAL = "03261421100"
M.WHATSAPP_INTL = "923261421100"
M.TARGET_CHARS_PER_PART = 3900
M.PAUSE_DURATION_MS = 380

-- Single Clean Mode Selector (1 to 6 Speakers)
M.MODE_LIST = {
    "Single Speaker (TTS & Story)",
    "2 Speakers Broadcast",
    "3 Speakers Broadcast",
    "4 Speakers Broadcast",
    "5 Speakers Broadcast",
    "6 Speakers Broadcast"
}

function M.getModeSpeakerCount(modeStr)
    local m = tostring(modeStr or "")
    local n = tonumber(m:match("^(%d+)%s+Speakers"))
    if n and n >= 2 and n <= 6 then return n end
    return 1
end

M.MODEL_LIST = {
    "gemini-3.8-flash-tts",
    "gemini-3.8-flash-lite-tts"
}
M.DEFAULT_MODEL = "gemini-3.8-flash-tts"

-- 30 Voices (Full list available for Single Speaker & All 6 Broadcast Speakers)
M.VOICE_LIST = {
    "Puck (Male)", "Kore (Female)", "Charon (Male)", "Zephyr (Female)",
    "Fenrir (Male)", "Leda (Female)", "Orus (Male)", "Aoede (Female)",
    "Callirrhoe (Female)", "Autonoe (Female)", "Enceladus (Male)", "Iapetus (Male)",
    "Umbriel (Male)", "Algieba (Female)", "Despina (Female)", "Erinome (Female)",
    "Algenib (Male)", "Rasalgethi (Male)", "Laomedeia (Female)", "Achernar (Male)",
    "Alnilam (Male)", "Schedar (Male)", "Gacrux (Male)", "Pulcherrima (Female)",
    "Achird (Friendly Male)", "Zubenelgenubi (Casual Male)", "Vindemiatrix (Gentle Female)",
    "Sadachbia (Lively Male)", "Sadaltager (Knowledgeable Male)", "Sulafat (Warm Female)"
}

M.RAW_VOICES = {
    "Puck", "Kore", "Charon", "Zephyr", "Fenrir", "Leda",
    "Orus", "Aoede", "Callirrhoe", "Autonoe", "Enceladus", "Iapetus",
    "Umbriel", "Algieba", "Despina", "Erinome", "Algenib", "Rasalgethi",
    "Laomedeia", "Achernar", "Alnilam", "Schedar", "Gacrux", "Pulcherrima",
    "Achird", "Zubenelgenubi", "Vindemiatrix", "Sadachbia", "Sadaltager", "Sulafat"
}

M.DEFAULT_SPK_VOICES = { "Puck", "Kore", "Charon", "Zephyr", "Fenrir", "Leda" }

function M.getVoiceDisplayName(rawVoice)
    for i, rv in ipairs(M.RAW_VOICES) do
        if rv == rawVoice then return M.VOICE_LIST[i] end
    end
    return tostring(rawVoice or "Puck")
end

-- 90 Languages (#1 Urdu Pakistan, #2 English USA, #3+ Global & Regional)
M.LANGUAGES = {
    "Urdu (Pakistan - اردو)",
    "English (USA)",
    "Roman Urdu (Pakistan - ABC)",
    "English (UK)",
    "English (India)",
    "English (Australia)",
    "Hindi (हिन्दी)",
    "Arabic (العربية)",
    "Punjabi (پنجابی)",
    "Pashto (پښتو)",
    "Sindhi (سنڌي)",
    "Balochi (بلوچی)",
    "Saraiki (سرائیکی)",
    "Kashmiri (کٲشُر)",
    "Persian / Farsi (فارسی)",
    "Bengali (বাংলা)",
    "Nepali (नेपाली)",
    "Tamil (தமிழ்)",
    "Telugu (తెలుగు)",
    "Marathi (मराठी)",
    "Gujarati (ગુજરાતી)",
    "Malayalam (മലയാളം)",
    "Kannada (ಕನ್ನಡ)",
    "Odia (ଓଡ଼ିଆ)",
    "Assamese (অসমীয়া)",
    "Sinhala (සිංහල)",
    "Turkish (Türkçe)",
    "Indonesian (Bahasa Indonesia)",
    "Malay (Bahasa Melayu)",
    "Chinese / Mandarin (中文)",
    "Cantonese (粵語)",
    "Japanese (日本語)",
    "Korean (한국어)",
    "Thai (ไทย)",
    "Vietnamese (Tiếng Việt)",
    "Filipino / Tagalog",
    "Burmese (မြန်မာ)",
    "Khmer (ខ្មែរ)",
    "Lao (ລາວ)",
    "Spanish (Spain)",
    "Spanish (Mexico / Latin)",
    "French (France)",
    "French (Canada)",
    "German (Deutsch)",
    "Italian (Italiano)",
    "Portuguese (Brazil)",
    "Portuguese (Portugal)",
    "Russian (Русский)",
    "Ukrainian (Українська)",
    "Polish (Polski)",
    "Dutch (Nederlands)",
    "Swedish (Svenska)",
    "Norwegian (Norsk)",
    "Danish (Dansk)",
    "Finnish (Suomi)",
    "Greek (Ελληνικά)",
    "Czech (Čeština)",
    "Slovak (Slovenčina)",
    "Hungarian (Magyar)",
    "Romanian (Română)",
    "Bulgarian (Български)",
    "Croatian (Hrvatski)",
    "Serbian (Српски)",
    "Bosnian (Bosanski)",
    "Slovenian (Slovenščina)",
    "Albanian (Shqip)",
    "Lithuanian (Lietuvių)",
    "Latvian (Latviešu)",
    "Estonian (Eesti)",
    "Icelandic (Íslenska)",
    "Irish (Gaeilge)",
    "Welsh (Cymraeg)",
    "Catalan (Català)",
    "Basque (Euskara)",
    "Galician (Galego)",
    "Hebrew (עברית)",
    "Azerbaijani (Azərbaycan)",
    "Kazakh (Қазақша)",
    "Uzbek (Oʻzbek)",
    "Tajik (Тоҷикӣ)",
    "Kyrgyz (Кыргызча)",
    "Turkmen (Türkmençe)",
    "Georgian (ქართული)",
    "Armenian (Հայերեն)",
    "Swahili (Kiswahili)",
    "Amharic (አማርኛ)",
    "Somali (Soomaali)",
    "Hausa",
    "Yoruba",
    "Afrikaans"
}

M.DURATION_LIST = {
    "1 Minute",
    "5 Minutes",
    "10 Minutes",
    "15 Minutes",
    "Custom Minutes"
}

-- 29 Upgraded Styles for Single Speaker Mode (100% Exact Mood Lock)
M.SINGLE_STYLE_LIST = {
    "Default / Normal",
    "Islamic: Tilawat (Quranic Slow & Melodic)",
    "Islamic: Hadees (Calm Scholar & Tarjuma)",
    "Islamic: Dua (Humble, Soft & Emotional)",
    "Islamic: Naat / Kalam (Sweet & Rhythmic)",
    "Islamic: Waqia / Story (Deep & Reverent)",
    "Motivational Speech / Khutba",
    "Podcast Host (Conversational)",
    "Storytelling (Rich & Expressive)",
    "Kids Storyteller (Warm & Playful)",
    "Bedtime / Calm Sleep (Soothing)",
    "Funny Jokes / Comedy (Punchy)",
    "Comedy / Lighthearted",
    "Poetry / Shayari (Deep & Rhythmic)",
    "Dramatic Monologue (Theatrical)",
    "Horror / Scary / Suspense",
    "Thriller / Mystery (Tense)",
    "Sad / Emotional (Heartfelt)",
    "Romantic / Soft (Gentle)",
    "Happy / Joyful (Energetic)",
    "Angry / Aggressive (Forceful)",
    "Whispering / Secretive (ASMR Soft)",
    "Sarcastic / Irony (Dry Wit)",
    "News Anchor (Formal & Crisp)",
    "Documentary / Informative",
    "Motivational / Inspiring",
    "Dynamic Human (Natural Emotion)",
    "Cartoon: Thin & Squeaky (Patli Aawaz)",
    "Cartoon: Thick & Goofy (Moti Aawaz)"
}

M.SINGLE_STYLE_TEXT = {
    ["Default / Normal"] = "natural, clear, balanced studio narrator with a strictly steady medium pace and warm neutral tone",
    ["Islamic: Tilawat (Quranic Slow & Melodic)"] = "reverent, slow, deeply spiritual and melodic Quranic Qirat style with measured breath pauses, elongated vowels, calm serenity, and strictly uniform slow recitation tempo",
    ["Islamic: Hadees (Calm Scholar & Tarjuma)"] = "dignified, respectful Islamic scholar reciting clearly with solemn reverence, gentle pauses between sentences, and a calm steady pace",
    ["Islamic: Dua (Humble, Soft & Emotional)"] = "deeply humble, trembling, soft pleading prayerful voice filled with sincerity, slow unhurried pace, and heartfelt emotion",
    ["Islamic: Naat / Kalam (Sweet & Rhythmic)"] = "sweet, soulful, melodic and rhythmic Naat recitation with respectful softness and steady poetic cadence",
    ["Islamic: Waqia / Story (Deep & Reverent)"] = "deep, solemn, captivating Islamic historical narrator with gravitas, clear articulation, and steady emotional flow",
    ["Motivational Speech / Khutba"] = "powerful, commanding, inspiring orator delivering a heartfelt speech with resonant clarity, purposeful pauses, and confident energy",
    ["Podcast Host (Conversational)"] = "friendly, relaxed, authentic solo podcast host speaking directly to a listener with natural warmth and smooth conversational rhythm",
    ["Storytelling (Rich & Expressive)"] = "master audiobook storyteller with vivid warmth, subtle narrative pacing, and engaging immersion without changing speaker identity",
    ["Kids Storyteller (Warm & Playful)"] = "cheerful, gentle, animated children's storyteller with bright clarity, playful warmth, and easy-to-follow pace",
    ["Bedtime / Calm Sleep (Soothing)"] = "ultra-calm, hushed, soothing bedtime voice with very slow tempo, soft breathy warmth, and peaceful relaxation",
    ["Funny Jokes / Comedy (Punchy)"] = "witty, upbeat stand-up comedian with crisp comedic timing, playful inflection, and light natural chuckle on punchlines",
    ["Comedy / Lighthearted"] = "cheerful, playful, lighthearted narrator with a smiling tone and lively steady rhythm",
    ["Poetry / Shayari (Deep & Rhythmic)"] = "deep, soulful classical poet voice with deliberate rhythmic pauses, emotional resonance, and lyrical flow",
    ["Dramatic Monologue (Theatrical)"] = "intense, theatrical stage actor delivering a gripping monologue with rich vocal weight and controlled dramatic pauses",
    ["Horror / Scary / Suspense"] = "eerie, low, chilling suspense narrator with slow creeping tension, hushed dread, and unsettling pauses",
    ["Thriller / Mystery (Tense)"] = "focused, taut, high-stakes thriller narrator with sharp urgency and controlled suspenseful pacing",
    ["Sad / Emotional (Heartfelt)"] = "sorrowful, tender, heavy-hearted voice with genuine quiet grief, slow pace, and soft emotional fragility",
    ["Romantic / Soft (Gentle)"] = "intimate, velvety, warm romantic voice with gentle tenderness and slow affectionate delivery",
    ["Happy / Joyful (Energetic)"] = "bright, joyful, enthusiastic voice radiating genuine happiness and upbeat energy",
    ["Angry / Aggressive (Forceful)"] = "intense, stern, forceful angry voice with sharp emphasis and controlled fiery authority",
    ["Whispering / Secretive (ASMR Soft)"] = "close, quiet, secretive whisper with delicate softness and steady hushed volume",
    ["Sarcastic / Irony (Dry Wit)"] = "deadpan, dry, sharply ironic narrator with subtle comedic skepticism and composed delivery",
    ["News Anchor (Formal & Crisp)"] = "authoritative, crisp, professional broadcast news anchor with strictly uniform medium pace and neutral precision",
    ["Documentary / Informative"] = "calm, knowledgeable, prestigious documentary narrator with clear articulation and measured informative cadence",
    ["Motivational / Inspiring"] = "uplifting, confident, encouraging mentor voice with strong clarity and inspiring momentum",
    ["Dynamic Human (Natural Emotion)"] = "highly lifelike, naturally expressive human speaker adapting smoothly to the text's emotion while keeping the exact same voice",
    ["Cartoon: Thin & Squeaky (Patli Aawaz)"] = "high-pitched, squeaky, quirky animated cartoon character voice kept consistent throughout",
    ["Cartoon: Thick & Goofy (Moti Aawaz)"] = "deep, booming, thick goofy cartoon character voice with slow playful charm kept consistent throughout"
}

-- 25 Moods for Multi-Speaker Broadcast Mode
M.BROADCAST_MOODS = {
    "Default / Normal",
    "Morning Show / Friendly Chat",
    "Comedy Banter",
    "Funny Jokes (Friends Jokes)",
    "Funny / Comedy",
    "Story & Discussion",
    "Storytelling",
    "Late Night Talk",
    "Educational Q&A",
    "Islamic / Spiritual",
    "Islamic Bayan / Waqia",
    "Tilawat / Quranic Reflection",
    "Romantic",
    "Sad / Emotional",
    "Informative / Educational",
    "News / Breaking",
    "Motivational / Inspiring",
    "Debate / Discussion",
    "Horror / Mystery",
    "Poetry / Shayari",
    "Thriller / Suspense",
    "Sarcastic / Roast",
    "Documentary / Deep Dive",
    "Kids / Cartoon Fun",
    "Interview / Talk Show"
}

-- Complete English (USA) User Guide
M.USER_GUIDE_TEXT = table.concat({
    "GEMINI AUDIO & BROADCAST STUDIO - USER GUIDE",
    "",
    "1. 5 API KEYS SMART FAILOVER & ROTATION:",
    "- Open SETTING -> SET API KEYS (1-5) to add up to 5 Google Gemini API Keys.",
    "- Requests rotate automatically across active keys. If Key 1 hits a quota limit or fails, the studio automatically switches to Key 2, Key 3, Key 4, and Key 5.",
    "",
    "2. CLEAN BUTTON INTERFACE & VOICE PREVIEW (3-5 SEC):",
    "- Tap Mode to switch between Single Speaker and 2 to 6 Speakers Broadcast.",
    "- Tap any Voice button to open the 30-voice list. Double-tap any voice to check it and immediately hear a 3-5 second cached sample without leaving the list. Tap DONE at the bottom to confirm your selection.",
    "- In Broadcast mode, optional friend names (e.g., Adnan, Usman) let speakers address each other naturally by name with realistic mixed turn-taking.",
    "",
    "3. 90 LANGUAGES & STRICT TONE / MOOD LOCK:",
    "- Tap Language to scroll smoothly through 90 languages (Urdu Pakistan #1, English USA #2, and 88 more).",
    "- Choose from 29 Single Speaker styles or 25 Broadcast moods. Long multi-part audio carries previous lines as context so voice, pitch, speed, and mood stay 100% consistent from Part 1 to Part 50+.",
    "",
    "4. LIVE PROGRESS, FOCUS LOCK, INSTANT STOP & SMART EXIT:",
    "- Tapping CREATE SCRIPT or GENERATE AUDIO moves focus directly to the Status bar with 5% step updates and live part counts.",
    "- Tap CLEAR TEXT (or clear the text box) anytime to stop active generation immediately and reset status to 0%.",
    "- Tap EXIT while a job is running to continue in the background. Tap EXIT after audio is finished to auto-clean temporary files."
}, "\n")

-- Preferences & Storage Paths
M.prefs = context.getSharedPreferences("Jieshuo_Gemini_ABS_V4", Context.MODE_PRIVATE)
M.baseStorageDir = context.getFilesDir() or context.getCacheDir()
M.previewCacheDir = File(context.getCacheDir() or M.baseStorageDir, "abs_v4_voice_previews")
if not M.previewCacheDir.exists() then M.previewCacheDir.mkdirs() end
M.resumeDir = File(M.baseStorageDir, "abs_v4_resume_parts")
if not M.resumeDir.exists() then M.resumeDir.mkdirs() end

-- Active User Config (5 API Keys)
M.cfg = {
    mode = "Single Speaker (TTS & Story)",
    speakerCount = 1,
    singleVoice = "Puck",
    singleStyle = "Default / Normal",
    speakerVoices = { "Puck", "Kore", "Charon", "Zephyr", "Fenrir", "Leda" },
    speakerNames = { "", "", "", "", "", "" },
    bcMood = "Default / Normal",
    lang = "Urdu (Pakistan - اردو)",
    duration = "1 Minute",
    customMinutes = "3",
    model = M.DEFAULT_MODEL,
    apiKeys = { "", "", "", "", "" },
    userText = ""
}
M.isUiInitializing = true
M.apiKeyCursor = 0
M.cachedScriptModels = nil
M.cachedTtsModels = nil

-- ============================================================
-- 5 API Keys Smart Rotation & Failover Helpers
-- ============================================================
function M.getActiveApiKeys()
    local list = {}
    for i = 1, 5 do
        local k = M.sanitizeKey(M.cfg.apiKeys[i] or "")
        if k ~= "" then table.insert(list, k) end
    end
    return list
end

function M.hasAnyApiKey()
    return #M.getActiveApiKeys() > 0
end

function M.getPrimaryApiKey()
    local list = M.getActiveApiKeys()
    if #list == 0 then return "" end
    M.apiKeyCursor = 1
    return list[1]
end

function M.getNextApiKey()
    local list = M.getActiveApiKeys()
    if #list == 0 then return "" end
    M.apiKeyCursor = (M.apiKeyCursor % #list) + 1
    return list[M.apiKeyCursor], M.apiKeyCursor, #list
end

function M.getAlternateApiKey(excludeKey)
    local list = M.getActiveApiKeys()
    if #list <= 1 then return nil end
    for i = 1, #list do
        M.apiKeyCursor = (M.apiKeyCursor % #list) + 1
        if list[M.apiKeyCursor] ~= excludeKey then
            return list[M.apiKeyCursor]
        end
    end
    return nil
end

-- ============================================================
-- Issue / Error Report Logger
-- ============================================================
function M.logIssue(source, message)
    pcall(function()
        local ts = os.date("%Y-%m-%d %H:%M:%S")
        local entry = string.format("[%s] Mode: %s | Model: %s | %s: %s",
            ts, tostring(M.cfg.mode), tostring(M.cfg.model), tostring(source), tostring(message))
        local existing = M.prefs.getString("issue_report_log", "")
        existing = (existing ~= "") and (existing .. "\n\n" .. entry) or entry
        if #existing > 8000 then existing = string.sub(existing, -8000) end
        local ed = M.prefs.edit()
        ed.putString("issue_report_log", existing)
        ed.commit()
    end)
end

function M.getIssueReport()
    return M.prefs.getString("issue_report_log", "")
end

function M.clearIssueReport()
    local ed = M.prefs.edit()
    ed.remove("issue_report_log")
    ed.commit()
end

-- ============================================================
-- Common Helpers, Focus Lock & Instant Job Cancel
-- ============================================================
function M.trim(s)
    return (tostring(s or ""):match("^%s*(.-)%s*$"))
end

function M.sanitizeKey(s)
    local t = M.trim(s)
    t = t:gsub("[\r\n%s\"'`]+", "")
    return t
end

function M.utf8CharCount(s)
    if not s or s == "" then return 0 end
    local count = 0
    for i = 1, #s do
        local b = string.byte(s, i)
        if b < 128 or b >= 192 then count = count + 1 end
    end
    return count
end

function M.getEffectiveMinutes()
    if M.cfg.duration == "Custom Minutes" then
        local n = tonumber(M.cfg.customMinutes)
        if not n or n < 1 then n = 1 end
        return math.floor(n)
    end
    local n = tonumber(tostring(M.cfg.duration):match("(%d+)"))
    return n or 1
end

function M.setBtnColor(btn, hex)
    pcall(function() btn.setBackgroundColor(Color.parseColor(hex)) end)
end

function M.runOnUi(callback)
    mainHandler.post(Runnable({
        run = function() pcall(callback) end
    }))
end

function M.delay(ms, callback)
    mainHandler.postDelayed(Runnable({
        run = function() pcall(callback) end
    }), ms)
end

function M.showToast(msg)
    M.runOnUi(function()
        pcall(function() Toast.makeText(context, tostring(msg), Toast.LENGTH_SHORT).show() end)
    end)
end

function M.speakOnly(msg)
    local ok = pcall(function() service.speak(tostring(msg)) end)
    if not ok then M.showToast(msg) end
end

-- Move Jieshuo Accessibility Focus directly to Status bar
function M.focusStatus()
    M.runOnUi(function()
        if S.ui and S.ui.statusText then
            pcall(function()
                S.ui.statusText.setFocusable(true)
                S.ui.statusText.setFocusableInTouchMode(true)
                S.ui.statusText.requestFocus()
                S.ui.statusText.sendAccessibilityEvent(AccessibilityEvent.TYPE_VIEW_FOCUSED)
            end)
        end
    end)
end

function M.updateProgress(pct, msg, shouldSpeak)
    if pct ~= nil then
        local p = math.max(0, math.min(100, math.floor(pct)))
        if p > 0 and p < 100 then
            p = math.max(5, math.min(95, math.floor((p + 2.5) / 5) * 5))
        end
        S.percent = p
    end
    if msg ~= nil then
        S.statusText = tostring(msg)
    end
    local displayStr = "[" .. tostring(S.percent) .. "%] " .. S.statusText

    M.runOnUi(function()
        if S.ui then
            if S.ui.statusText then
                pcall(function() S.ui.statusText.setText(displayStr) end)
            end
            if S.ui.generateBtn and S.isGenerating then
                pcall(function()
                    S.ui.generateBtn.setEnabled(false)
                    S.ui.generateBtn.setText("GENERATING AUDIO (" .. tostring(S.percent) .. "%)...")
                    M.setBtnColor(S.ui.generateBtn, "#9E9E9E")
                end)
            end
            if S.ui.createScriptBtn and S.isWritingScript then
                pcall(function()
                    S.ui.createScriptBtn.setEnabled(false)
                    S.ui.createScriptBtn.setText("WRITING SCRIPT (" .. tostring(S.percent) .. "%)...")
                    M.setBtnColor(S.ui.createScriptBtn, "#9E9E9E")
                end)
            end
        end
    end)

    if shouldSpeak and msg then
        M.speakOnly(msg)
    end
end


-- ============================================================
-- Persistent Disk Checkpoint & Auto-Resume Engine (Survives Phone Restart)
-- Parts are ONLY deleted on Download, Clear Text, or starting a brand-new text
-- ============================================================
function M.makeAudioSig(text, mode)
    local t = M.trim(tostring(text or ""))
    local m = tostring(mode or "")
    local len = #t
    local h1, h2 = 5381, 2166136261
    local step = math.max(1, math.floor(len / 400))
    for i = 1, len, step do
        local b = string.byte(t, i) or 0
        h1 = ((h1 * 33) + b) % 2147483647
        h2 = ((h2 * 16777619) + b) % 2147483647
    end
    return m .. "|" .. tostring(len) .. "|" .. tostring(h1) .. "|" .. tostring(h2)
end

function M.getResumePartFile(idx)
    if not M.resumeDir.exists() then M.resumeDir.mkdirs() end
    return File(M.resumeDir, "part_" .. tostring(idx) .. ".pcm")
end

function M.clearAudioResume()
    pcall(function()
        if M.resumeDir and M.resumeDir.exists() then
            local files = M.resumeDir.listFiles()
            if files then
                for i = 0, #files - 1 do
                    pcall(function() if files[i] and files[i].exists() then files[i].delete() end end)
                end
            end
        end
    end)
    pcall(function()
        local ed = M.prefs.edit()
        ed.remove("res_audio_sig")
        ed.remove("res_audio_mode")
        ed.remove("res_audio_total")
        ed.commit()
    end)
end

function M.saveAudioResumeMeta(sig, mode, totalParts)
    pcall(function()
        local ed = M.prefs.edit()
        ed.putString("res_audio_sig", tostring(sig or ""))
        ed.putString("res_audio_mode", tostring(mode or ""))
        ed.putInt("res_audio_total", tonumber(totalParts) or 0)
        ed.commit()
    end)
end

function M.getAudioResumeStatus(currentText, currentMode)
    local t = M.trim(tostring(currentText or ""))
    if t == "" then return 0, 0, 1 end
    local savedSig = M.prefs.getString("res_audio_sig", "")
    local totalParts = M.prefs.getInt("res_audio_total", 0)
    if savedSig == "" or totalParts <= 0 then return 0, 0, 1 end
    local curSig = M.makeAudioSig(t, currentMode or M.cfg.mode)
    if savedSig ~= curSig then return 0, 0, 1 end

    local doneCount = 0
    local firstMissing = nil
    for i = 1, totalParts do
        local f = M.getResumePartFile(i)
        if f and f.exists() and f.length() > 100 then
            doneCount = doneCount + 1
        elseif not firstMissing then
            firstMissing = i
        end
    end
    return doneCount, totalParts, firstMissing
end

function M.clearScriptResume()
    pcall(function()
        local ed = M.prefs.edit()
        ed.remove("res_script_topic")
        ed.remove("res_script_mode")
        ed.remove("res_script_mins")
        ed.remove("res_script_total")
        ed.remove("res_script_done")
        ed.commit()
    end)
end

function M.saveScriptResume(topic, mode, mins, totalBatches, doneBatches)
    pcall(function()
        local ed = M.prefs.edit()
        ed.putString("res_script_topic", tostring(topic or ""))
        ed.putString("res_script_mode", tostring(mode or ""))
        ed.putInt("res_script_mins", tonumber(mins) or 1)
        ed.putInt("res_script_total", tonumber(totalBatches) or 0)
        ed.putInt("res_script_done", tonumber(doneBatches) or 0)
        ed.commit()
    end)
end

function M.getScriptResumeStatus()
    local total = M.prefs.getInt("res_script_total", 0)
    local done = M.prefs.getInt("res_script_done", 0)
    local savedMode = M.prefs.getString("res_script_mode", "")
    if total <= 0 or done <= 0 or done >= total then
        return 0, 0, nil, nil, 0
    end
    if savedMode ~= "" and savedMode ~= M.cfg.mode then
        return 0, 0, nil, nil, 0
    end
    if M.trim(M.cfg.userText or "") == "" then
        return 0, 0, nil, nil, 0
    end
    local topic = M.prefs.getString("res_script_topic", "")
    local mins = M.prefs.getInt("res_script_mins", M.getEffectiveMinutes())
    return done, total, topic, savedMode, mins
end

function M.clearLastWavPrefs()
    pcall(function()
        local ed = M.prefs.edit()
        ed.remove("last_wav_path")
        ed.remove("last_wav_dur")
        ed.commit()
    end)
end

function M.cancelAndResetSession(speakNotice)
    S.jobId = (S.jobId or 0) + 1
    S.isGenerating = false
    S.isWritingScript = false
    S.percent = 0
    S.statusText = "Status: Ready"

    if S.mediaPlayer ~= nil then
        pcall(function()
            if S.isPlaying then S.mediaPlayer.stop() end
            S.mediaPlayer.release()
        end)
        S.mediaPlayer = nil
        S.isPlaying = false
    end
    M.deleteOldAudioFile()
    M.clearAudioResume()
    M.clearScriptResume()
    M.clearLastWavPrefs()

    M.runOnUi(function()
        if S.ui then
            pcall(function()
                if S.ui.resultLayout then S.ui.resultLayout.setVisibility(View.GONE) end
                if S.ui.playBtn then
                    S.ui.playBtn.setEnabled(false)
                    S.ui.playBtn.setText("PLAY")
                end
                if S.ui.statusText then S.ui.statusText.setText("[0%] Status: Ready") end
            end)
        end
    end)
    if M.refreshActionButtons then M.refreshActionButtons() end
    if speakNotice then M.speakOnly(speakNotice) end
end

function M.safe(name, fn)
    return function(...)
        local args = {...}
        local ok, err = pcall(function() return fn(table.unpack(args)) end)
        if not ok then
            S.isGenerating = false
            S.isWritingScript = false
            M.logIssue("CodeError:" .. tostring(name), tostring(err))
            M.updateProgress(S.percent, "Code error (" .. name .. "): " .. tostring(err), true)
            if M.refreshActionButtons then M.refreshActionButtons() end
        end
    end
end

function M.saveSettings()
    local ed = M.prefs.edit()
    ed.putString("mode", M.cfg.mode)
    ed.putInt("speaker_count", M.getModeSpeakerCount(M.cfg.mode))
    ed.putString("single_voice", M.cfg.singleVoice)
    ed.putString("single_style", M.cfg.singleStyle)
    for i = 1, 6 do
        ed.putString("spk_voice_" .. i, M.cfg.speakerVoices[i] or M.DEFAULT_SPK_VOICES[i])
        ed.putString("spk_name_" .. i, M.cfg.speakerNames[i] or "")
    end
    ed.putString("bc_mood", M.cfg.bcMood)
    ed.putString("lang", M.cfg.lang)
    ed.putString("duration", M.cfg.duration)
    ed.putString("custom_minutes", M.cfg.customMinutes)
    ed.putString("model", M.cfg.model)
    for i = 1, 5 do
        ed.putString("apikey_" .. i, M.cfg.apiKeys[i] or "")
    end
    ed.commit()
end

function M.saveDraftText(txt)
    local ed = M.prefs.edit()
    ed.putString("draft_text", txt or "")
    ed.commit()
end

function M.loadSettings()
    local savedMode = M.prefs.getString("mode", M.MODE_LIST[1])
    local validMode = false
    for _, m in ipairs(M.MODE_LIST) do
        if m == savedMode then validMode = true break end
    end
    M.cfg.mode = validMode and savedMode or M.MODE_LIST[1]
    M.cfg.speakerCount = M.getModeSpeakerCount(M.cfg.mode)

    M.cfg.singleVoice = M.prefs.getString("single_voice", "Puck")
    M.cfg.singleStyle = M.prefs.getString("single_style", "Default / Normal")
    for i = 1, 6 do
        M.cfg.speakerVoices[i] = M.prefs.getString("spk_voice_" .. i, M.DEFAULT_SPK_VOICES[i])
        M.cfg.speakerNames[i] = M.prefs.getString("spk_name_" .. i, "")
    end
    M.cfg.bcMood = M.prefs.getString("bc_mood", M.BROADCAST_MOODS[1])
    M.cfg.lang = M.prefs.getString("lang", M.LANGUAGES[1])
    M.cfg.duration = M.prefs.getString("duration", "1 Minute")
    M.cfg.customMinutes = M.prefs.getString("custom_minutes", "3")
    M.cfg.model = M.prefs.getString("model", M.DEFAULT_MODEL)
    for i = 1, 5 do
        M.cfg.apiKeys[i] = M.sanitizeKey(M.prefs.getString("apikey_" .. i, ""))
    end
    if M.cfg.apiKeys[1] == "" then
        local oldPrefs = context.getSharedPreferences("Jieshuo_Gemini_ABS_V3", Context.MODE_PRIVATE)
        for i = 1, 3 do
            local okK = M.sanitizeKey(oldPrefs.getString("apikey_" .. i, ""))
            if okK ~= "" then M.cfg.apiKeys[i] = okK end
        end
    end
    M.cfg.userText = M.prefs.getString("draft_text", "")

    local validM = false
    for _, m in ipairs(M.MODEL_LIST) do
        if m == M.cfg.model then validM = true break end
    end
    if not validM then
        M.cfg.model = M.DEFAULT_MODEL
        M.saveSettings()
    end

    if not S.generatedAudioPath then
        local savedWav = M.prefs.getString("last_wav_path", "")
        if savedWav ~= "" then
            local wf = File(savedWav)
            if wf.exists() and wf.length() > 100 then
                S.generatedAudioPath = savedWav
                S.currentDurationStr = M.prefs.getString("last_wav_dur", "")
            else
                M.clearLastWavPrefs()
            end
        end
    end
end

function M.formatDurationText(totalSeconds)
    if not totalSeconds or totalSeconds < 0 then totalSeconds = 0 end
    totalSeconds = math.floor(totalSeconds + 0.5)
    local mins = math.floor(totalSeconds / 60)
    local secs = math.floor(totalSeconds % 60)
    if mins > 0 then
        return string.format("%d min %02d sec", mins, secs), string.format("%d minute %d second", mins, secs)
    else
        return string.format("0 min %02d sec", secs), string.format("%d second", secs)
    end
end

function M.extractApiError(content)
    local msg = nil
    pcall(function()
        local d = cjson.decode(content)
        if d and d.error and d.error.message then msg = d.error.message end
    end)
    return msg
end

-- ============================================================
-- HTTP Helpers & Fast Cached Script Model Discovery
-- ============================================================
function M.httpPost(url, body, headers, cb)
    local wrappedCb = function(code, content)
        local ok, err = pcall(cb, code, content)
        if not ok then
            S.isGenerating = false
            S.isWritingScript = false
            M.logIssue("HttpPostCallback", tostring(err))
            M.updateProgress(S.percent, "Response Error: " .. tostring(err), true)
            if M.refreshActionButtons then M.refreshActionButtons() end
        end
    end
    local ok1, r1 = pcall(function() return Http.post(url, body, headers, wrappedCb) end)
    if ok1 then return true, r1 end
    local ok2, r2 = pcall(function() return Http.post(url, body, nil, "utf8", headers, wrappedCb) end)
    if ok2 then return true, r2 end
    local errStr = tostring(r1) .. " | " .. tostring(r2)
    M.logIssue("HttpPost", errStr)
    return false, errStr
end

function M.httpGet(url, cb)
    local wrappedCb = function(code, content) pcall(cb, code, content) end
    local ok1, r1 = pcall(function() return Http.get(url, wrappedCb) end)
    if ok1 then return true, r1 end
    local ok2, r2 = pcall(function() return Http.get(url, nil, wrappedCb) end)
    if ok2 then return true, r2 end
    local errStr = tostring(r1) .. " | " .. tostring(r2)
    M.logIssue("HttpGet", errStr)
    return false, errStr
end

function M.discoverAllWorkingModels(apikey, callback)
    if M.cachedScriptModels and #M.cachedScriptModels > 0 and M.cachedTtsModels then
        callback(M.cachedScriptModels, M.cachedTtsModels, nil)
        return
    end
    local url = "https://generativelanguage.googleapis.com/v1beta/models?key=" .. apikey
    local okGet, errGet = M.httpGet(url, function(code, content)
        if code ~= 200 then
            local msg = "Models list error (" .. tostring(code) .. "): " .. tostring(M.extractApiError(content) or "")
            M.logIssue("ListModels", msg)
            callback(nil, nil, msg)
            return
        end
        local okDec, data = pcall(cjson.decode, content)
        if not okDec or not data or not data.models then
            M.logIssue("ListModels", "Invalid JSON response")
            callback(nil, nil, "Models list could not be parsed.")
            return
        end

        local fastFlashText, otherFlashText, otherText = {}, {}, {}
        local fastFlashTts, otherTts = {}, {}

        for _, m in ipairs(data.models) do
            local shortName = tostring(m.name or ""):gsub("^models/", "")
            local lower = shortName:lower()
            local supportsGen = false
            if type(m.supportedGenerationMethods) == "table" then
                for _, meth in ipairs(m.supportedGenerationMethods) do
                    if meth == "generateContent" then supportsGen = true break end
                end
            end

            if supportsGen and lower:find("gemini", 1, true) then
                if lower:find("tts", 1, true) then
                    if lower:find("flash", 1, true) then
                        table.insert(fastFlashTts, shortName)
                    else
                        table.insert(otherTts, shortName)
                    end
                elseif not lower:find("image", 1, true)
                    and not lower:find("audio", 1, true)
                    and not lower:find("embedding", 1, true)
                    and not lower:find("veo", 1, true)
                    and not lower:find("robotics", 1, true)
                    and not lower:find("computer", 1, true) then
                    if lower:find("flash-lite", 1, true) then
                        table.insert(fastFlashText, shortName)
                    elseif lower:find("flash", 1, true) then
                        table.insert(otherFlashText, shortName)
                    else
                        table.insert(otherText, shortName)
                    end
                end
            end
        end

        table.sort(fastFlashText, function(a, b) return a > b end)
        table.sort(otherFlashText, function(a, b) return a > b end)
        table.sort(otherText, function(a, b) return a > b end)
        table.sort(fastFlashTts, function(a, b) return a > b end)
        table.sort(otherTts, function(a, b) return a > b end)

        -- Fastest Flash text models first for fast script writing
        local scriptList = {}
        for _, v in ipairs(otherFlashText) do table.insert(scriptList, v) end
        for _, v in ipairs(fastFlashText) do table.insert(scriptList, v) end
        for _, v in ipairs(otherText) do table.insert(scriptList, v) end

        -- Fastest Flash TTS models first, followed by Pro / other active TTS models
        local ttsList = {}
        for _, v in ipairs(fastFlashTts) do table.insert(ttsList, v) end
        for _, v in ipairs(otherTts) do table.insert(ttsList, v) end

        M.cachedScriptModels = scriptList
        M.cachedTtsModels = ttsList
        callback(scriptList, ttsList, nil)
    end)
    if not okGet then
        M.logIssue("ListModels", tostring(errGet))
        callback(nil, nil, "Models check failed: " .. tostring(errGet))
    end
end

function M.discoverWorkingScriptModels(apikey, callback)
    M.discoverAllWorkingModels(apikey, function(scriptList, _, err)
        if err then
            callback(nil, err)
        elseif not scriptList or #scriptList == 0 then
            M.logIssue("ListModels", "No text generation models available")
            callback(nil, "No active text model found for this API Key.")
        else
            callback(scriptList, nil)
        end
    end)
end

function M.discoverWorkingTtsModels(apikey, primaryModel, callback)
    local function buildQueue(discoveredTts)
        local queue, seen = {}, {}
        local function addM(m)
            if m and m ~= "" and not seen[m] then
                seen[m] = true
                table.insert(queue, m)
            end
        end
        addM(primaryModel)
        if discoveredTts then
            for _, m in ipairs(discoveredTts) do addM(m) end
        end
        for _, m in ipairs(M.MODEL_LIST) do addM(m) end
        return queue
    end

    if M.cachedTtsModels and #M.cachedTtsModels > 0 then
        callback(buildQueue(M.cachedTtsModels))
        return
    end

    M.discoverAllWorkingModels(apikey, function(_, ttsList, _)
        callback(buildQueue(ttsList))
    end)
end

-- ============================================================
-- Media Player, WAV/PCM Engine & 3-5s Cached Voice Sample Preview
-- ============================================================
function M.deleteOldAudioFile()
    if S.generatedAudioPath then
        pcall(function()
            local f = File(S.generatedAudioPath)
            if f.exists() then f.delete() end
        end)
        S.generatedAudioPath = nil
        S.currentDurationStr = ""
    end
end

function M.stopPreviewPlayer()
    if S.previewPlayer ~= nil then
        pcall(function()
            if S.previewPlayer.isPlaying() then S.previewPlayer.stop() end
            S.previewPlayer.release()
        end)
        S.previewPlayer = nil
    end
end

function M.playPreviewFile(wavPath)
    M.runOnUi(function()
        M.stopPreviewPlayer()
        pcall(function()
            local mp = MediaPlayer()
            S.previewPlayer = mp
            mp.setDataSource(wavPath)
            mp.setOnCompletionListener(MediaPlayer.OnCompletionListener({
                onCompletion = function() M.stopPreviewPlayer() end
            }))
            mp.prepare()
            mp.start()
        end)
    end)
end

function M.initMediaPlayer()
    if S.mediaPlayer ~= nil then
        if S.isPlaying then
            pcall(function() S.mediaPlayer.stop() end)
            S.isPlaying = false
        end
        pcall(function() S.mediaPlayer.release() end)
    end
    S.mediaPlayer = MediaPlayer()
    S.mediaPlayer.setOnCompletionListener(MediaPlayer.OnCompletionListener({
        onCompletion = function(mp)
            S.isPlaying = false
            M.speakOnly("Playback completed.")
            M.runOnUi(function()
                if S.ui and S.ui.playBtn then
                    S.ui.playBtn.setText(S.currentDurationStr ~= "" and ("PLAY (" .. S.currentDurationStr .. ")") or "PLAY")
                end
            end)
        end
    }))
end

function M.togglePlayPause(playBtn)
    if not S.generatedAudioPath or not File(S.generatedAudioPath).exists() then
        M.speakOnly("No audio loaded.")
        return
    end
    M.stopPreviewPlayer()
    if S.mediaPlayer == nil then
        M.initMediaPlayer()
        S.mediaPlayer.setDataSource(S.generatedAudioPath)
        S.mediaPlayer.prepare()
    end
    if S.isPlaying then
        pcall(function() S.mediaPlayer.pause() end)
        S.isPlaying = false
        M.runOnUi(function()
            playBtn.setText(S.currentDurationStr ~= "" and ("PLAY (" .. S.currentDurationStr .. ")") or "PLAY")
        end)
    else
        local ok = pcall(function() S.mediaPlayer.start() end)
        if ok then
            S.isPlaying = true
            M.runOnUi(function()
                playBtn.setText(S.currentDurationStr ~= "" and ("PAUSE (" .. S.currentDurationStr .. ")") or "PAUSE")
            end)
        end
    end
end

function M.writeWavHeader(outStream, totalAudioLen)
    local sampleRate, channels, bitsPerSample = 24000, 1, 16
    local byteRate = sampleRate * channels * (bitsPerSample // 8)
    local blockAlign = channels * (bitsPerSample // 8)
    local totalSize = totalAudioLen + 36
    local function gb(v)
        v = math.floor(v)
        return { v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff }
    end
    local ts, sr, br, dl = gb(totalSize), gb(sampleRate), gb(byteRate), gb(totalAudioLen)
    local header = {
        0x52,0x49,0x46,0x46, ts[1],ts[2],ts[3],ts[4], 0x57,0x41,0x56,0x45,
        0x66,0x6d,0x74,0x20, 0x10,0x00,0x00,0x00, 0x01,0x00,
        channels & 0xff,(channels >> 8) & 0xff, sr[1],sr[2],sr[3],sr[4],
        br[1],br[2],br[3],br[4], blockAlign & 0xff,(blockAlign >> 8) & 0xff,
        bitsPerSample & 0xff,(bitsPerSample >> 8) & 0xff,
        0x64,0x61,0x74,0x61, dl[1],dl[2],dl[3],dl[4]
    }
    for i = 1, #header do outStream.write(header[i]) end
end

local function detectArrayBase(arr)
    local ok0, v0 = pcall(function() return arr[0] end)
    return (ok0 and v0 ~= nil) and 0 or 1
end

local function readUByte(arr, pos, base)
    local ok, val = pcall(function() return arr[pos + base] end)
    if not ok or val == nil then return 0 end
    return val < 0 and (val + 256) or val
end

function M.extractCleanPcmSegment(audioBytes)
    local totalLen = #audioBytes
    if totalLen <= 100 then return 0, 0 end
    local base = detectArrayBase(audioBytes)
    local pcmStart, exactDataEnd = 0, totalLen

    if readUByte(audioBytes, 0, base) == 82 and readUByte(audioBytes, 1, base) == 73
        and readUByte(audioBytes, 2, base) == 70 and readUByte(audioBytes, 3, base) == 70 then
        pcmStart = 44
        local limit = math.min(totalLen - 12, 1024)
        for i = 12, limit do
            if readUByte(audioBytes, i, base) == 100 and readUByte(audioBytes, i + 1, base) == 97
                and readUByte(audioBytes, i + 2, base) == 116 and readUByte(audioBytes, i + 3, base) == 97 then
                local declared = readUByte(audioBytes, i + 4, base)
                    + (readUByte(audioBytes, i + 5, base) * 256)
                    + (readUByte(audioBytes, i + 6, base) * 65536)
                    + (readUByte(audioBytes, i + 7, base) * 16777216)
                pcmStart = i + 8
                if declared > 0 and (pcmStart + declared) <= totalLen then
                    exactDataEnd = pcmStart + declared
                end
                break
            end
        end
    end

    if pcmStart % 2 ~= 0 then pcmStart = pcmStart + 1 end

    local avail = exactDataEnd - pcmStart
    if avail > 12000 then
        pcmStart = pcmStart + 640
        exactDataEnd = exactDataEnd - 1920
    elseif avail > 2400 then
        pcmStart = pcmStart + 200
        exactDataEnd = exactDataEnd - 400
    end

    local pcmLen = exactDataEnd - pcmStart
    if pcmLen % 2 ~= 0 then pcmLen = pcmLen - 1 end
    if pcmLen <= 0 then return 0, 0 end
    return pcmStart, pcmLen
end

-- 3 to 5 Second Voice Sample Preview (Cached Locally)
function M.previewVoiceSample(voiceName)
    if not voiceName or voiceName == "" then return end
    if S.isGenerating or S.isWritingScript then return end

    local cacheFile = File(M.previewCacheDir, "preview_" .. tostring(voiceName) .. ".wav")
    if cacheFile.exists() and cacheFile.length() > 1000 then
        M.playPreviewFile(cacheFile.getAbsolutePath())
        return
    end

    local apiKey = M.getNextApiKey()
    if apiKey == "" then return end

    local headers = HashMap()
    headers.put("Content-Type", "application/json")
    local sampleText = "Hello! I am " .. tostring(voiceName) .. ". This is a short preview of how my voice sounds in Gemini Audio Studio."
    local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. tostring(M.cfg.model) .. ":generateContent?key=" .. apiKey

    local payload = {
        contents = { { role = "user", parts = { { text = sampleText } } } },
        generationConfig = {
            responseModalities = { "AUDIO" },
            speechConfig = { voiceConfig = { voice = voiceName } }
        }
    }

    M.httpPost(url, cjson.encode(payload), headers, function(code, content)
        if code ~= 200 then return end
        local okDec, data = pcall(cjson.decode, content)
        if not okDec or not data or not data.candidates or #data.candidates == 0 then return end
        local cand = data.candidates[1]
        if not cand.content or not cand.content.parts then return end

        local byteArrays, totalPcm = {}, 0
        for i = 1, #cand.content.parts do
            local inl = cand.content.parts[i].inlineData or cand.content.parts[i].inline_data
            if inl and inl.data then
                local okB, bArr = pcall(function() return Base64.decode(inl.data, Base64.DEFAULT) end)
                if okB and bArr and #bArr > 0 then
                    local off, len = M.extractCleanPcmSegment(bArr)
                    if len > 0 then
                        table.insert(byteArrays, { arr = bArr, off = off, len = len })
                        totalPcm = totalPcm + len
                    end
                end
            end
        end
        if totalPcm <= 0 then return end

        local okW = pcall(function()
            local fos = FileOutputStream(cacheFile)
            M.writeWavHeader(fos, totalPcm)
            for _, seg in ipairs(byteArrays) do
                fos.write(seg.arr, seg.off, seg.len)
            end
            fos.flush()
            fos.close()
        end)
        if okW and cacheFile.exists() and cacheFile.length() > 1000 then
            M.playPreviewFile(cacheFile.getAbsolutePath())
        end
    end)
end
-- ============================================================
-- PART 2 OF 3: Parsers, Create Script Engine & Audio Engines (Launch v4)
-- (5-Key Auto-Failover + 2-3 Lines Tone Lock + Focus Lock + Instant Cancel)
-- ============================================================

function M.refreshActionButtons()
    M.runOnUi(function()
        if not S.ui then return end

        if S.ui.createScriptBtn then
            if S.isWritingScript then
                S.ui.createScriptBtn.setEnabled(false)
                S.ui.createScriptBtn.setText("WRITING SCRIPT (" .. tostring(S.percent) .. "%)...")
                M.setBtnColor(S.ui.createScriptBtn, "#9E9E9E")
            elseif S.isGenerating then
                S.ui.createScriptBtn.setEnabled(false)
                S.ui.createScriptBtn.setText("CREATE SCRIPT")
                M.setBtnColor(S.ui.createScriptBtn, "#9E9E9E")
            else
                S.ui.createScriptBtn.setEnabled(true)
                local doneS, totalS = M.getScriptResumeStatus()
                if doneS > 0 and doneS < totalS then
                    S.ui.createScriptBtn.setText("RESUME SCRIPT (" .. tostring(doneS) .. "/" .. tostring(totalS) .. ")")
                    M.setBtnColor(S.ui.createScriptBtn, "#8E24AA")
                else
                    S.ui.createScriptBtn.setText("CREATE SCRIPT")
                    M.setBtnColor(S.ui.createScriptBtn, "#6A1B9A")
                end
            end
        end

        if S.ui.generateBtn then
            if S.isGenerating then
                S.ui.generateBtn.setEnabled(false)
                S.ui.generateBtn.setText("GENERATING AUDIO (" .. tostring(S.percent) .. "%)...")
                M.setBtnColor(S.ui.generateBtn, "#9E9E9E")
            elseif S.isWritingScript then
                S.ui.generateBtn.setEnabled(false)
                S.ui.generateBtn.setText("GENERATE AUDIO")
                M.setBtnColor(S.ui.generateBtn, "#9E9E9E")
            else
                S.ui.generateBtn.setEnabled(true)
                local doneA, totalA = M.getAudioResumeStatus(M.cfg.userText, M.cfg.mode)
                if doneA > 0 and doneA < totalA then
                    S.ui.generateBtn.setText("RESUME AUDIO (" .. tostring(doneA) .. "/" .. tostring(totalA) .. ")")
                    M.setBtnColor(S.ui.generateBtn, "#00897B")
                else
                    S.ui.generateBtn.setText("GENERATE AUDIO")
                    M.setBtnColor(S.ui.generateBtn, "#2196F3")
                end
            end
        end
    end)
end

-- ============================================================
-- Temp PCM Helpers, WAV Merger & UI Completion
-- ============================================================
local function cleanupTempFiles(filesList)
    if not filesList then return end
    for _, f in ipairs(filesList) do
        pcall(function() if f and f.exists() then f.delete() end end)
    end
end

local function decodeAudioPartsFromResponse(content)
    local okDec, data = pcall(cjson.decode, content)
    local byteArrays = {}
    if okDec and data and data.candidates and #data.candidates > 0 then
        local cand = data.candidates[1]
        if cand.content and cand.content.parts then
            for i = 1, #cand.content.parts do
                local inl = cand.content.parts[i].inlineData or cand.content.parts[i].inline_data
                if inl and inl.data then
                    local okB, bArr = pcall(function() return Base64.decode(inl.data, Base64.DEFAULT) end)
                    if okB and bArr and #bArr > 0 then
                        table.insert(byteArrays, bArr)
                    end
                end
            end
        end
    end
    return byteArrays
end

local function writePcmArraysToFile(partFile, byteArrays)
    local okSave, errSave = pcall(function()
        local fos = FileOutputStream(partFile)
        for i = 1, #byteArrays do
            local off, len = M.extractCleanPcmSegment(byteArrays[i])
            if len > 0 then
                fos.write(byteArrays[i], off, len)
            end
        end
        fos.flush()
        fos.close()
    end)
    if not okSave or not partFile.exists() or partFile.length() <= 100 then
        pcall(function() if partFile.exists() then partFile.delete() end end)
        return false, tostring(errSave or "Empty PCM file")
    end
    return true, nil
end

function M.mergePcmFilesToWav(partFilesList, pauseMs, filePrefix)
    local totalDurationSec = 0
    local okMerge, errMerge = pcall(function()
        M.deleteOldAudioFile()
        local finalPath = M.baseStorageDir.getPath() .. "/" .. filePrefix .. "_" .. os.time() .. ".wav"
        local pauseBytes = math.floor((24000 * 2 * (pauseMs or 300)) / 1000)
        if pauseBytes % 2 ~= 0 then pauseBytes = pauseBytes + 1 end

        local validItems = {}
        local totalPcmBytes = 0
        for _, f in ipairs(partFilesList) do
            if f and f.exists() and f.length() > 100 then
                local len = math.floor(f.length())
                if len % 2 ~= 0 then len = len - 1 end
                table.insert(validItems, { file = f, length = len })
                totalPcmBytes = totalPcmBytes + len
            end
        end

        if #validItems > 1 and pauseBytes > 0 then
            totalPcmBytes = totalPcmBytes + ((#validItems - 1) * pauseBytes)
        end
        if totalPcmBytes <= 0 then error("Audio data is empty") end

        totalDurationSec = totalPcmBytes / 48000.0
        local fos = FileOutputStream(File(finalPath))
        M.writeWavHeader(fos, totalPcmBytes)

        local copyBuf = byte[32768]
        local silenceBuf = (pauseBytes > 0) and byte[pauseBytes] or nil

        for idx, item in ipairs(validItems) do
            local fis = FileInputStream(item.file)
            local rem = item.length
            while rem > 0 do
                local r = fis.read(copyBuf, 0, math.min(32768, rem))
                if not r or r <= 0 then break end
                fos.write(copyBuf, 0, r)
                rem = rem - r
            end
            fis.close()
            if idx < #validItems and silenceBuf then
                fos.write(silenceBuf, 0, pauseBytes)
            end
        end

        fos.flush()
        fos.close()
        S.generatedAudioPath = finalPath
    end)

    if not okMerge or not S.generatedAudioPath then
        M.logIssue("MergeWAV", tostring(errMerge))
        return false, tostring(errMerge)
    end
    return true, totalDurationSec
end

function M.onAudioReadyUI(totalDurationSec, labelPrefix)
    local shortDur = M.formatDurationText(totalDurationSec)
    S.currentDurationStr = shortDur
    S.isGenerating = false
    pcall(function()
        local ed = M.prefs.edit()
        ed.putString("last_wav_path", tostring(S.generatedAudioPath or ""))
        ed.putString("last_wav_dur", tostring(shortDur or ""))
        ed.commit()
    end)
    M.updateProgress(100, labelPrefix .. " Ready (" .. shortDur .. ")", true)

    M.runOnUi(function()
        if S.ui then
            pcall(function()
                if S.ui.resultLayout then S.ui.resultLayout.setVisibility(View.VISIBLE) end
                if S.ui.durationLabel then
                    S.ui.durationLabel.setText(labelPrefix .. " Length: " .. S.currentDurationStr)
                end
                if S.ui.playBtn then
                    S.ui.playBtn.setText("PLAY (" .. S.currentDurationStr .. ")")
                    S.ui.playBtn.setEnabled(true)
                end
            end)
        end
    end)
    M.refreshActionButtons()
end

-- ============================================================
-- Multi-Speaker (1 to 6) & Single-Speaker Text Parsers
-- ============================================================
function M.extractSpeakerAndBody(rawLine, maxSpeakers)
    local maxS = maxSpeakers or 6
    local l = M.trim(rawLine):gsub("^[%*%-%•%d%.%)%s]+", ""):gsub("%*", ""):gsub("%b[]", "")
    l = M.trim(l)
    if l == "" then return nil, "" end

    local spkIdx, body = nil, l
    local sNum, rest = l:match("^[Ss]peaker%s*([1-6])%s*[:%-–—]+%s*(.*)")
    if not sNum then
        sNum, rest = l:match("^[Hh]ost%s*([1-6])%s*[:%-–—]+%s*(.*)")
    end

    if sNum then
        local idx = tonumber(sNum)
        if idx and idx >= 1 and idx <= maxS then
            spkIdx = idx
            body = M.trim(rest)
        end
    elseif l:match("^[Mm]ale%s*[:%-–—]") then
        spkIdx = 1
        body = M.trim(l:gsub("^[Mm]ale%s*[:%-–—]+", ""))
    elseif l:match("^[Ff]emale%s*[:%-–—]") then
        spkIdx = 2
        body = M.trim(l:gsub("^[Ff]emale%s*[:%-–—]+", ""))
    else
        for i = 1, maxS do
            local customN = M.trim(M.cfg.speakerNames[i] or "")
            if customN ~= "" then
                local esc = customN:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
                local mBody = l:match("^" .. esc .. "%s*[:%-–—]+%s*(.*)")
                if mBody then
                    spkIdx = i
                    body = M.trim(mBody)
                    break
                end
            end
        end
    end

    body = M.trim(body:gsub("[Ss]peaker%s*[1-6]%s*:?", ""):gsub("[Hh]ost%s*[1-6]%s*:?", ""))
    if spkIdx then
        return "Speaker" .. tostring(spkIdx), body, spkIdx
    end
    return nil, body, nil
end

function M.normalizeBcScript(rawText, maxSpeakers)
    local text = tostring(rawText or ""):gsub("\r\n", "\n")
    local sec = text:match("%-%-%-%s*Script%s*%-%-%-\n?(.*)")
    if sec then text = sec end

    local lines, count = {}, 0
    for line in text:gmatch("[^\n]+") do
        local spk, body = M.extractSpeakerAndBody(line, maxSpeakers or 6)
        if spk and body ~= "" then
            count = count + 1
            table.insert(lines, spk .. ": " .. body)
        end
    end
    if count >= 2 then return true, table.concat(lines, "\n") end
    return false, nil
end

function M.parseBcTurnsIntoChunks(scriptText)
    local allTurns, lastSpk = {}, "Speaker1"
    for line in scriptText:gmatch("[^\n]+") do
        local spk, body = M.extractSpeakerAndBody(line, 2)
        if body ~= "" then
            spk = spk or lastSpk
            lastSpk = spk
            table.insert(allTurns, { speaker = spk, text = body })
        end
    end

    local chunks, cur, chars = {}, {}, 0
    for _, t in ipairs(allTurns) do
        local tChars = M.utf8CharCount(t.text)
        if #cur > 0 and (#cur >= 80 or (chars + tChars) > 4000) then
            table.insert(chunks, cur)
            cur, chars = {}, 0
        end
        table.insert(cur, t)
        chars = chars + tChars
    end
    if #cur > 0 then table.insert(chunks, cur) end
    return chunks
end

function M.parseGroupSpeakerBatches(scriptText, speakerCount)
    local allTurns = {}
    local lastIdx = 1
    for line in scriptText:gmatch("[^\n]+") do
        local spk, body, idx = M.extractSpeakerAndBody(line, speakerCount)
        if body ~= "" then
            idx = idx or lastIdx
            if idx > speakerCount then idx = 1 end
            lastIdx = idx
            if #allTurns > 0 and allTurns[#allTurns].speakerIdx == idx
                and (M.utf8CharCount(allTurns[#allTurns].text) + M.utf8CharCount(body)) < 3800 then
                allTurns[#allTurns].text = allTurns[#allTurns].text .. " " .. body
            else
                table.insert(allTurns, { speakerIdx = idx, text = body })
            end
        end
    end

    local batches = {}
    local curTurns, curSpkList, curSpkSet, curChars = {}, {}, {}, 0

    for _, t in ipairs(allTurns) do
        local tChars = M.utf8CharCount(t.text)
        local alreadyIn = curSpkSet[t.speakerIdx] == true
        local wouldExceedSpeakers = (not alreadyIn) and (#curSpkList >= 2)
        local wouldExceedSize = (#curTurns > 0) and (#curTurns >= 80 or (curChars + tChars) > 4000)

        if wouldExceedSpeakers or wouldExceedSize then
            table.insert(batches, { speakers = curSpkList, turns = curTurns })
            curTurns, curSpkList, curSpkSet, curChars = {}, {}, {}, 0
            alreadyIn = false
        end

        if not alreadyIn then
            curSpkSet[t.speakerIdx] = true
            table.insert(curSpkList, t.speakerIdx)
        end
        table.insert(curTurns, t)
        curChars = curChars + tChars
    end

    if #curTurns > 0 then
        table.insert(batches, { speakers = curSpkList, turns = curTurns })
    end
    return batches
end

function M.normalizeSingleChunk(chunk)
    chunk = chunk:gsub("!+", "."):gsub("%?+", "?"):gsub("؟+", "؟")
    chunk = chunk:gsub("%.%.%.+", "."):gsub("—", ", "):gsub("%-%-+", ", ")
    chunk = chunk:gsub("[\"\'“”‘’«»%*]", ""):gsub("\n+", " "):gsub("%s+", " ")
    chunk = M.trim(chunk)
    local l1, l2, l3 = string.sub(chunk, -1), string.sub(chunk, -2), string.sub(chunk, -3)
    if l1 ~= "." and l1 ~= "?" and l2 ~= "۔" and l2 ~= "؟" and l3 ~= "।" then
        chunk = chunk .. "."
    end
    return chunk
end

function M.findCleanBoundary(str, targetBytePos)
    local len = #str
    if targetBytePos >= len or targetBytePos <= 1 then return len end
    local minB = math.max(1, targetBytePos - 450)
    local maxB = math.min(len, targetBytePos + 450)

    local bestPos, bestDist = nil, 999999
    for i = minB, maxB do
        local c = string.sub(str, i, i)
        local isEnd, endIdx = false, i
        if c == "." or c == "?" or c == "!" or c == "\n" then
            isEnd = true
        else
            local b1, b2, b3 = string.byte(str, i, i + 2)
            if (b1 == 219 and b2 == 148) or (b1 == 216 and b2 == 159) then
                isEnd, endIdx = true, i + 1
            elseif b1 == 224 and b2 == 165 and b3 == 164 then
                isEnd, endIdx = true, i + 2
            end
        end
        if isEnd then
            local dist = math.abs(endIdx - targetBytePos)
            if dist < bestDist then bestDist, bestPos = dist, endIdx end
        end
    end
    if bestPos then return bestPos end

    local sMin, sMax = math.max(1, targetBytePos - 700), math.min(len, targetBytePos + 700)
    for i = sMin, sMax do
        local c = string.sub(str, i, i)
        if c == " " or c == "\t" or c == "\n" then
            local dist = math.abs(i - targetBytePos)
            if dist < bestDist then bestDist, bestPos = dist, i end
        end
    end
    if bestPos then return bestPos end

    local pos = targetBytePos
    while pos < len do
        local b = string.byte(str, pos + 1)
        if not b or b < 128 or b >= 192 then break end
        pos = pos + 1
    end
    return pos
end

function M.splitSingleTextIntoChunks(text)
    local t = M.trim(tostring(text or ""):gsub("\r\n", "\n"))
    if t == "" then return {} end

    local totalChars = M.utf8CharCount(t)
    if totalChars <= 4000 then
        return { M.normalizeSingleChunk(t) }
    end

    local numParts = math.max(1, math.ceil(totalChars / M.TARGET_CHARS_PER_PART))
    local rawChunks, remaining, partsLeft = {}, t, numParts

    while partsLeft > 1 and #remaining > 0 do
        local cut = M.findCleanBoundary(remaining, math.floor(#remaining / partsLeft))
        local c = M.trim(string.sub(remaining, 1, cut))
        if c ~= "" then table.insert(rawChunks, c) end
        remaining = M.trim(string.sub(remaining, cut + 1))
        partsLeft = partsLeft - 1
    end
    if #remaining > 0 then table.insert(rawChunks, remaining) end

    if #rawChunks > 1 and M.utf8CharCount(rawChunks[#rawChunks]) < 400 then
        rawChunks[#rawChunks - 1] = rawChunks[#rawChunks - 1] .. " " .. rawChunks[#rawChunks]
        table.remove(rawChunks, #rawChunks)
    end

    local finalChunks = {}
    for _, c in ipairs(rawChunks) do
        table.insert(finalChunks, M.normalizeSingleChunk(c))
    end
    return finalChunks
end

-- ============================================================
-- FAST "CREATE SCRIPT" ENGINE
-- (5-Key Auto-Failover + Optional Friend Names + Natural Mixing)
-- ============================================================
function M.startCreateScriptJob(inputText)
    S.jobId = (S.jobId or 0) + 1
    local myJobId = S.jobId
    S.isWritingScript = true
    M.refreshActionButtons()
    M.focusStatus()

    local spkCount = M.getModeSpeakerCount(M.cfg.mode)
    local isSingle = (spkCount == 1)
    local lang = M.cfg.lang
    local totalMins = M.getEffectiveMinutes()

    local headers = HashMap()
    headers.put("Content-Type", "application/json")

    local function isCanceled()
        return S.jobId ~= myJobId
    end

    local function failScript(msg)
        if isCanceled() then return end
        S.isWritingScript = false
        M.logIssue("CreateScript", msg)
        local dS, tS = M.getScriptResumeStatus()
        if dS > 0 and dS < tS then
            local savedPct = math.max(10, math.floor((dS / tS) * 85) + 10)
            M.updateProgress(savedPct, msg .. " (" .. tostring(dS) .. "/" .. tostring(tS) .. " parts safely saved. Tap RESUME SCRIPT.)", true)
        else
            M.updateProgress(0, msg, true)
        end
        M.refreshActionButtons()
    end

    local primaryKey = M.getPrimaryApiKey()
    if primaryKey == "" then
        failScript("No API Key set. Please add at least 1 API Key in Settings.")
        return
    end

    local speakerRosterStr = ""
    local namedFriends = {}
    if not isSingle then
        local rList = {}
        for i = 1, spkCount do
            local customN = M.trim(M.cfg.speakerNames[i] or "")
            local voiceName = M.cfg.speakerVoices[i] or M.DEFAULT_SPK_VOICES[i]
            if customN ~= "" then
                table.insert(rList, "Speaker" .. i .. " = " .. customN .. " (Voice: " .. voiceName .. ")")
                table.insert(namedFriends, customN)
            else
                table.insert(rList, "Speaker" .. i .. " (Voice: " .. voiceName .. ")")
            end
        end
        speakerRosterStr = table.concat(rList, ", ")
    end

    local resDone, resTotal, resTopic, _, resMins = M.getScriptResumeStatus()
    local isResumingScript = (resDone > 0 and resDone < resTotal)
    local effectiveTopic = isResumingScript and (resTopic or inputText) or inputText
    if isResumingScript and resMins and resMins > 0 then
        totalMins = resMins
    end

    local batches = {}
    local remMins = totalMins
    while remMins > 0 do
        local chunkMins = math.min(15, remMins)
        table.insert(batches, { mins = chunkMins })
        remMins = remMins - chunkMins
    end

    local totalBatches = #batches
    local startBatchIdx = 1
    local accumulatedScript = ""

    if isResumingScript and resTotal == totalBatches then
        accumulatedScript = M.cfg.userText or ""
        startBatchIdx = resDone + 1
        M.updateProgress(math.max(10, math.floor((resDone / totalBatches) * 85) + 10),
            "Resuming script from part " .. tostring(startBatchIdx) .. "/" .. tostring(totalBatches) .. "...", true)
    else
        M.clearScriptResume()
        if totalBatches > 1 then
            M.saveScriptResume(effectiveTopic, M.cfg.mode, totalMins, totalBatches, 0)
        end
        M.updateProgress(5, "Preparing fast script engine...", true)
    end

    M.discoverWorkingScriptModels(primaryKey, function(models, discErr)
        if isCanceled() then return end
        if discErr or not models or #models == 0 then
            failScript(discErr or "No active script model found.")
            return
        end

        local function buildBatchPrompt(bIdx)
            local b = batches[bIdx]
            local words = b.mins * 145
            local turns = math.max(8, b.mins * 7)
            local lines = {}

            if isSingle then
                table.insert(lines, "Write an engaging single-narrator script/story.")
                table.insert(lines, "Language: " .. lang .. ".")
                table.insert(lines, "Exact Style / Mood: " .. M.cfg.singleStyle .. ".")
                table.insert(lines, "Target Length: approx " .. tostring(b.mins) .. " minute(s) (~" .. tostring(words) .. " words).")
                table.insert(lines, "STRICT RULES: Output ONLY clean spoken narration text matching the exact mood and language. No markdown stars (*), no headings (#), no brackets [], no emojis.")
            else
                table.insert(lines, "Write a 100% realistic, natural, lively conversation between " .. tostring(spkCount) .. " friends/hosts: " .. speakerRosterStr .. ".")
                table.insert(lines, "Language: " .. lang .. ".")
                table.insert(lines, "Exact Mood / Style: " .. M.cfg.bcMood .. ".")
                table.insert(lines, "Target Length: approx " .. tostring(b.mins) .. " minute(s) (~" .. tostring(turns) .. " dialogue turns, ~" .. tostring(words) .. " words).")
                table.insert(lines, "STRICT RULES:")
                table.insert(lines, "1. Every line MUST start with Speaker1:, Speaker2:, ... up to Speaker" .. tostring(spkCount) .. ": ONLY as the prefix.")
                table.insert(lines, "2. NEVER say 'Speaker1', 'Speaker2', 'Host 1', or any label inside the spoken dialogue.")
                if #namedFriends > 0 then
                    table.insert(lines, "3. IMPORTANT: The friends MUST address each other naturally by their real names (" .. table.concat(namedFriends, ", ") .. ") in the dialogue just like real friends talking together.")
                else
                    table.insert(lines, "3. IMPORTANT: No custom names were given. Do NOT invent random personal names; keep the friendly conversation completely natural without forcing names.")
                end
                if spkCount >= 3 then
                    table.insert(lines, "4. Structure the group conversation in longer, natural 2-speaker back-and-forth exchanges/scenes (let 2 speakers talk together for 10 to 14 turns before smoothly bringing in the next speaker so everyone participates naturally with minimal scene switches).")
                else
                    table.insert(lines, "4. Keep the 2-speaker conversation lively, natural, and engaging with smooth back-and-forth replies.")
                end
                table.insert(lines, "5. No brackets [], parentheses (), asterisks *, emojis, or stage directions. Output ONLY the clean dialogue lines.")
            end

            if bIdx == 1 then
                if M.trim(inputText) ~= "" then
                    table.insert(lines, "User Topic / Instructions:\n" .. inputText)
                end
            else
                local tailContext = string.sub(accumulatedScript, -1200)
                table.insert(lines, "CONTINUATION (Part " .. tostring(bIdx) .. "/" .. tostring(totalBatches) .. "):")
                table.insert(lines, "Continue SEAMLESSLY right after the last sentence below without repeating or adding a new intro.\nLast lines:\n" .. tailContext)
            end

            return table.concat(lines, "\n")
        end

        local function runBatch(bIdx, modelIdx, curKey, useFastThinking, keyRetries)
            if isCanceled() then return end
            local curModel = models[modelIdx]
            if not curModel then
                failScript("All script models failed at part " .. tostring(bIdx) .. "/" .. tostring(totalBatches) .. ". Check Report Issue.")
                return
            end

            local basePct = math.max(10, math.floor(((bIdx - 1) / totalBatches) * 85) + 10)
            local batchLabel = (totalBatches > 1)
                and ("Writing script part " .. tostring(bIdx) .. "/" .. tostring(totalBatches) .. " (" .. curModel .. ")...")
                or ("Writing " .. tostring(totalMins) .. " min script (" .. curModel .. ")...")
            M.updateProgress(basePct, batchLabel, false)

            local payload = {
                contents = { { role = "user", parts = { { text = buildBatchPrompt(bIdx) } } } }
            }
            if useFastThinking then
                payload.generationConfig = { thinkingConfig = { thinkingBudget = 0 } }
            end

            local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. curModel .. ":generateContent?key=" .. curKey

            local okS, errS = M.httpPost(url, cjson.encode(payload), headers, function(code, content)
                if isCanceled() then return end

                if code == 400 and useFastThinking then
                    M.delay(100, function() runBatch(bIdx, modelIdx, curKey, false, keyRetries) end)
                    return
                end

                if code == 429 or code == 503 or code == 500 or code == -1 or code == 404 then
                    M.logIssue("ScriptBatch" .. tostring(bIdx), "Model " .. curModel .. " HTTP " .. tostring(code) .. ": " .. tostring(M.extractApiError(content) or "Busy"))
                    local altKey = M.getAlternateApiKey(curKey)
                    if altKey and keyRetries < 4 then
                        M.updateProgress(basePct, "Key busy (code " .. tostring(code) .. "), switching API key...", false)
                        M.delay(250, function() runBatch(bIdx, modelIdx, altKey, useFastThinking, keyRetries + 1) end)
                        return
                    end
                    if modelIdx < #models then
                        M.updateProgress(basePct, "Model busy (code " .. tostring(code) .. "), switching model...", false)
                        M.delay(300, function() runBatch(bIdx, modelIdx + 1, curKey, true, 0) end)
                        return
                    end
                end

                if code == 200 then
                    local okJ, data = pcall(cjson.decode, content)
                    local outText = nil
                    if okJ and data and data.candidates and data.candidates[1]
                        and data.candidates[1].content and data.candidates[1].content.parts
                        and data.candidates[1].content.parts[1] then
                        outText = data.candidates[1].content.parts[1].text
                    end

                    if not outText or M.trim(outText) == "" then
                        failScript("Script part " .. tostring(bIdx) .. " returned empty response.")
                        return
                    end

                    local cleanPart
                    if isSingle then
                        cleanPart = M.trim(outText:gsub("%*", ""):gsub("%b[]", ""):gsub("#+", ""))
                    else
                        local _, cleanFmt = M.normalizeBcScript(outText, spkCount)
                        cleanPart = cleanFmt or M.trim(outText:gsub("%*", ""):gsub("%b[]", ""))
                    end

                    accumulatedScript = (accumulatedScript == "") and cleanPart or (accumulatedScript .. "\n\n" .. cleanPart)
                    M.cfg.userText = accumulatedScript
                    M.saveDraftText(accumulatedScript)

                    M.runOnUi(function()
                        if isCanceled() then return end
                        if S.ui and S.ui.textInput then
                            M.isUiInitializing = true
                            pcall(function()
                                S.ui.textInput.setText(accumulatedScript)
                                if S.ui.charCounter then
                                    S.ui.charCounter.setText(tostring(S.ui.textInput.getText().length()) .. " chars (Unlimited)")
                                end
                            end)
                            M.isUiInitializing = false
                        end
                    end)

                    if bIdx < totalBatches then
                        M.saveScriptResume(effectiveTopic, M.cfg.mode, totalMins, totalBatches, bIdx)
                        local donePct = math.max(10, math.floor((bIdx / totalBatches) * 85) + 10)
                        M.updateProgress(donePct, "Script part " .. tostring(bIdx) .. "/" .. tostring(totalBatches) .. " saved. Continuing...", false)
                        M.delay(100, function()
                            runBatch(bIdx + 1, modelIdx, M.getNextApiKey(), useFastThinking, 0)
                        end)
                    else
                        M.clearScriptResume()
                        S.isWritingScript = false
                        M.updateProgress(100, "Script Ready! Review it and tap GENERATE AUDIO.", true)
                        M.refreshActionButtons()
                    end
                else
                    failScript("Script Error (" .. tostring(code) .. "): " .. tostring(M.extractApiError(content) or "Server error"))
                end
            end)

            if not okS then failScript("Script request failed: " .. tostring(errS)) end
        end

        runBatch(startBatchIdx, 1, primaryKey, true, 0)
    end)
end

-- ============================================================
-- ENGINE 1: SINGLE SPEAKER AUDIO ENGINE
-- (2-3 Lines Tone/Pitch/Mood Lock + 5-Key Failover + Live Parts Count)
-- ============================================================
function M.startSingleSpeakerAudioJob(inputText)
    S.jobId = (S.jobId or 0) + 1
    local myJobId = S.jobId
    S.isGenerating = true
    M.refreshActionButtons()
    M.focusStatus()

    local voice = M.cfg.singleVoice
    local style = M.cfg.singleStyle
    local lang = M.cfg.lang
    local primaryModel = M.cfg.model

    local headers = HashMap()
    headers.put("Content-Type", "application/json")

    local ttsQueue = { primaryModel }
    for _, m in ipairs(M.MODEL_LIST) do
        if m ~= primaryModel then table.insert(ttsQueue, m) end
    end

    local function isCanceled()
        return S.jobId ~= myJobId
    end

    local function stopOnError(msg)
        if isCanceled() then return end
        S.isGenerating = false
        M.logIssue("SingleAudio", msg)
        local dA, tA = M.getAudioResumeStatus(inputText, M.cfg.mode)
        if dA > 0 and dA < tA then
            local savedPct = math.max(5, math.floor((dA / tA) * 90))
            M.updateProgress(savedPct, msg .. " (" .. tostring(dA) .. "/" .. tostring(tA) .. " parts safely saved. Tap RESUME AUDIO.)", true)
        else
            M.updateProgress(0, msg, true)
        end
        M.refreshActionButtons()
    end

    if not M.hasAnyApiKey() then
        stopOnError("No API Key set. Please add at least 1 API Key in Settings.")
        return
    end

    local bodyOnly = inputText:match("%-%-%-%s*Story%s*%-%-%-\n?(.*)") or inputText
    local chunks = M.splitSingleTextIntoChunks(M.trim(bodyOnly))
    local totalParts = #chunks
    if totalParts == 0 then
        stopOnError("Text is empty. Cannot generate audio.")
        return
    end

    local baseStyle = M.SINGLE_STYLE_TEXT[style] or M.SINGLE_STYLE_TEXT["Default / Normal"]

    local audioSig = M.makeAudioSig(inputText, M.cfg.mode)
    local doneA, savedTotalA, firstMissingA = M.getAudioResumeStatus(inputText, M.cfg.mode)
    local startIdx = 1
    if savedTotalA == totalParts and doneA > 0 then
        startIdx = firstMissingA or (totalParts + 1)
    else
        M.clearAudioResume()
        M.saveAudioResumeMeta(audioSig, M.cfg.mode, totalParts)
        startIdx = 1
    end

    local function finishMerge()
        if isCanceled() then return end
        local allFiles = {}
        for i = 1, totalParts do table.insert(allFiles, M.getResumePartFile(i)) end
        M.updateProgress(95, "Merging all " .. tostring(totalParts) .. " audio parts...", false)
        local okM, durOrErr = M.mergePcmFilesToWav(allFiles, M.PAUSE_DURATION_MS, "gemini_single")
        if isCanceled() then M.deleteOldAudioFile() return end
        if not okM then
            stopOnError("Merge error: " .. tostring(durOrErr))
            return
        end
        M.onAudioReadyUI(durOrErr, "Audio")
    end

    local function processChunk(partIdx, ttsIdx, modeIdx, curKey, keyRetries)
        if isCanceled() then return end
        local curModel = ttsQueue[ttsIdx]
        if not curModel then
            stopOnError("Failed at Part " .. tostring(partIdx) .. "/" .. tostring(totalParts) .. ". Check Report Issue.")
            return
        end

        local doneBefore = partIdx - 1
        local pct = math.max(5, math.floor((doneBefore / totalParts) * 90))
        M.updateProgress(pct, "Audio Part " .. tostring(partIdx) .. "/" .. tostring(totalParts) .. " generating...", partIdx == 1 and modeIdx == 1 and keyRetries == 0)

        -- Carry last 2-3 lines of previous part so tone, pitch, speed & mood stay 100% locked
        local continuityLock
        if partIdx > 1 then
            local prevTail = string.sub(chunks[partIdx - 1] or "", -320)
            continuityLock = "100% STRICT CONTINUITY LOCK: You are continuing seamlessly right after these previous lines: '" .. prevTail
                .. "'. Keep the EXACT SAME speaker voice (" .. voice .. "), identical vocal pitch, identical mood (" .. style
                .. "), identical speaking speed, and identical emotional delivery with ZERO shift in tone or style."
        else
            continuityLock = "100% STRICT VOICE & MOOD LOCK: Perform strictly in the exact mood (" .. style
                .. ") with speaker voice (" .. voice .. "), maintaining uniform pitch, volume, and steady pace from start to finish."
        end

        local stylePrompt = baseStyle .. ". Language: " .. lang .. ". " .. continuityLock

        local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. curModel .. ":generateContent?key=" .. curKey
        local partObj = { text = chunks[partIdx] }
        if modeIdx == 3 then
            partObj.speechMetadata = { style = stylePrompt }
        else
            partObj.speech_metadata = { style = stylePrompt }
        end

        local genCfg = {
            responseModalities = { "AUDIO" },
            speechConfig = { voiceConfig = { voice = voice } }
        }
        if modeIdx == 1 then
            genCfg.temperature = 0.0
            genCfg.seed = 424242
        elseif modeIdx == 2 then
            genCfg.temperature = 0.05
            genCfg.seed = 424242
        end

        local payload = {
            contents = { { role = "user", parts = { partObj } } },
            generationConfig = genCfg
        }

        local okP, errP = M.httpPost(url, cjson.encode(payload), headers, function(code, content)
            if isCanceled() then return end

            if code == 400 and modeIdx < 4 then
                M.delay(100, function() processChunk(partIdx, ttsIdx, modeIdx + 1, curKey, keyRetries) end)
                return
            end

            if code == 429 or code == 503 or code == 500 or code == -1 or code == 404 then
                M.logIssue("SinglePart" .. tostring(partIdx), "Model " .. curModel .. " HTTP " .. tostring(code) .. ": " .. tostring(M.extractApiError(content) or "Busy"))
                local altKey = M.getAlternateApiKey(curKey)
                if altKey and keyRetries < 4 then
                    M.delay(250, function() processChunk(partIdx, ttsIdx, modeIdx, altKey, keyRetries + 1) end)
                    return
                elseif ttsIdx < #ttsQueue then
                    M.delay(300, function() processChunk(partIdx, ttsIdx + 1, 1, M.getNextApiKey(), 0) end)
                    return
                end
            end

            if code == 200 then
                local byteArrays = decodeAudioPartsFromResponse(content)
                if #byteArrays == 0 then
                    stopOnError("Part " .. tostring(partIdx) .. " returned empty audio.")
                    return
                end

                local pf = M.getResumePartFile(partIdx)
                local okSave, errSave = writePcmArraysToFile(pf, byteArrays)
                if not okSave then
                    stopOnError("Part " .. tostring(partIdx) .. " save error: " .. tostring(errSave))
                    return
                end

                local donePct = math.max(5, math.floor((partIdx / totalParts) * 90))
                M.updateProgress(donePct, "Audio Part " .. tostring(partIdx) .. "/" .. tostring(totalParts) .. " done", false)

                if partIdx < totalParts then
                    M.delay(50, function() processChunk(partIdx + 1, ttsIdx, modeIdx, M.getNextApiKey(), 0) end)
                else
                    finishMerge()
                end
            else
                stopOnError("Part " .. tostring(partIdx) .. " error (" .. tostring(code) .. "): " .. tostring(M.extractApiError(content) or "Server error"))
            end
        end)
        if not okP then stopOnError("Request failed: " .. tostring(errP)) end
    end

    if startIdx > totalParts then
        finishMerge()
        return
    end
    local firstKey = M.getNextApiKey()
    if startIdx > 1 then
        M.updateProgress(math.max(5, math.floor(((startIdx - 1) / totalParts) * 90)),
            "Resuming from Part " .. tostring(startIdx) .. "/" .. tostring(totalParts) .. " (" .. tostring(startIdx - 1) .. " saved)...", true)
    else
        M.updateProgress(5, "Checking active audio models...", false)
    end
    M.discoverWorkingTtsModels(firstKey, primaryModel, function(discoveredQueue)
        if isCanceled() then return end
        if discoveredQueue and #discoveredQueue > 0 then
            ttsQueue = discoveredQueue
        end
        processChunk(startIdx, 1, 1, firstKey, 0)
    end)
end

-- ============================================================
-- ENGINE 2: MULTI-SPEAKER BROADCAST ENGINE (2 to 6 Speakers)
-- (5-Key Auto-Failover + Part-to-Part Tone Lock + Live Parts Count)
-- ============================================================
function M.startBroadcastAudioJob(inputText)
    S.jobId = (S.jobId or 0) + 1
    local myJobId = S.jobId
    S.isGenerating = true
    M.refreshActionButtons()
    M.focusStatus()

    local spkCount = M.getModeSpeakerCount(M.cfg.mode)
    if spkCount < 2 then spkCount = 2 end
    local lang = M.cfg.lang
    local mood = M.cfg.bcMood
    local primaryModel = M.cfg.model

    local headers = HashMap()
    headers.put("Content-Type", "application/json")

    local ttsQueue = { primaryModel }
    for _, m in ipairs(M.MODEL_LIST) do
        if m ~= primaryModel then table.insert(ttsQueue, m) end
    end

    local function isCanceled()
        return S.jobId ~= myJobId
    end

    local function stopOnError(msg)
        if isCanceled() then return end
        S.isGenerating = false
        M.logIssue("BroadcastAudio", msg)
        local dA, tA = M.getAudioResumeStatus(inputText, M.cfg.mode)
        if dA > 0 and dA < tA then
            local savedPct = math.max(5, math.floor((dA / tA) * 90))
            M.updateProgress(savedPct, msg .. " (" .. tostring(dA) .. "/" .. tostring(tA) .. " parts safely saved. Tap RESUME AUDIO.)", true)
        else
            M.updateProgress(0, msg, true)
        end
        M.refreshActionButtons()
    end

    if not M.hasAnyApiKey() then
        stopOnError("No API Key set. Please add at least 1 API Key in Settings.")
        return
    end

    local isValid, cleanScript = M.normalizeBcScript(inputText, spkCount)
    if not isValid or not cleanScript then
        stopOnError("Broadcast script not detected. Tap CREATE SCRIPT first to generate " .. tostring(spkCount) .. "-speaker dialogue.")
        return
    end

    -- PATH A: 2-Speaker Fast Native Multi-Speaker Engine
    if spkCount <= 2 then
        local turnChunks = M.parseBcTurnsIntoChunks(cleanScript)
        local totalParts = #turnChunks
        if totalParts == 0 then
            stopOnError("Script format not found. Tap CREATE SCRIPT first.")
            return
        end

        local v1 = M.cfg.speakerVoices[1] or M.DEFAULT_SPK_VOICES[1]
        local v2 = M.cfg.speakerVoices[2] or M.DEFAULT_SPK_VOICES[2]

        local audioSig = M.makeAudioSig(inputText, M.cfg.mode)
        local doneA, savedTotalA, firstMissingA = M.getAudioResumeStatus(inputText, M.cfg.mode)
        local startIdx = 1
        if savedTotalA == totalParts and doneA > 0 then
            startIdx = firstMissingA or (totalParts + 1)
        else
            M.clearAudioResume()
            M.saveAudioResumeMeta(audioSig, M.cfg.mode, totalParts)
            startIdx = 1
        end

        local function finishMerge()
            if isCanceled() then return end
            local allFiles = {}
            for i = 1, totalParts do table.insert(allFiles, M.getResumePartFile(i)) end
            M.updateProgress(95, "Merging all " .. tostring(totalParts) .. " broadcast parts...", false)
            local okM, durOrErr = M.mergePcmFilesToWav(allFiles, 280, "gemini_broadcast")
            if isCanceled() then M.deleteOldAudioFile() return end
            if not okM then
                stopOnError("Merge error: " .. tostring(durOrErr))
                return
            end
            M.onAudioReadyUI(durOrErr, "Broadcast")
        end

        local function processBcPart(partIdx, ttsIdx, modeIdx, curKey, keyRetries)
            if isCanceled() then return end
            local curModel = ttsQueue[ttsIdx]
            if not curModel then
                stopOnError("Failed at Part " .. tostring(partIdx) .. "/" .. tostring(totalParts) .. ". Check Report Issue.")
                return
            end

            local pct = math.max(5, math.floor(((partIdx - 1) / totalParts) * 90))
            M.updateProgress(pct, "Broadcast Part " .. tostring(partIdx) .. "/" .. tostring(totalParts) .. " generating...", partIdx == 1 and modeIdx == 1 and keyRetries == 0)

            local contNote = ""
            if partIdx > 1 and turnChunks[partIdx - 1] and #turnChunks[partIdx - 1] > 0 then
                local lastTurn = turnChunks[partIdx - 1][#turnChunks[partIdx - 1]]
                contNote = ", continuing seamlessly after '" .. string.sub(lastTurn.text or "", -180) .. "' with zero change in voice, pitch, or speed"
            end

            local s1Style = "consistent broadcast friend (" .. v1 .. ") speaking in " .. lang
                .. ", strictly matching exact mood: " .. mood .. ", locked to identical voice identity, vocal pitch, and steady tempo" .. contNote
            local s2Style = "consistent broadcast friend (" .. v2 .. ") speaking in " .. lang
                .. ", strictly matching exact mood: " .. mood .. ", locked to identical voice identity, vocal pitch, and steady tempo" .. contNote

            local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. curModel .. ":generateContent?key=" .. curKey
            local partsArray = {}
            for _, turn in ipairs(turnChunks[partIdx]) do
                local st = (turn.speaker == "Speaker1") and s1Style or s2Style
                if modeIdx <= 2 then
                    table.insert(partsArray, { text = turn.text, speech_metadata = { speaker = turn.speaker, style = st } })
                elseif modeIdx == 3 then
                    table.insert(partsArray, { text = turn.text, speech_metadata = { speaker = turn.speaker } })
                else
                    table.insert(partsArray, { text = turn.text, speechMetadata = { speaker = turn.speaker } })
                end
            end

            local spkCfgs = (modeIdx <= 3) and {
                { speaker = "Speaker1", voiceConfig = { voice = v1 } },
                { speaker = "Speaker2", voiceConfig = { voice = v2 } }
            } or {
                { speaker = "Speaker1", voiceConfig = { prebuiltVoiceConfig = { voiceName = v1 } } },
                { speaker = "Speaker2", voiceConfig = { prebuiltVoiceConfig = { voiceName = v2 } } }
            }

            local genCfg = {
                responseModalities = { "AUDIO" },
                speechConfig = { multiSpeakerVoiceConfig = { speakerVoiceConfigs = spkCfgs } }
            }
            if modeIdx == 1 then
                genCfg.temperature = 0.0
                genCfg.seed = 424242
            elseif modeIdx == 2 then
                genCfg.temperature = 0.05
                genCfg.seed = 424242
            end

            local payload = {
                contents = { { role = "user", parts = partsArray } },
                generationConfig = genCfg
            }

            local okP, errP = M.httpPost(url, cjson.encode(payload), headers, function(code, content)
                if isCanceled() then return end

                if code == 400 and modeIdx < 4 then
                    M.delay(100, function() processBcPart(partIdx, ttsIdx, modeIdx + 1, curKey, keyRetries) end)
                    return
                end

                if code == 429 or code == 503 or code == 500 or code == -1 or code == 404 then
                    M.logIssue("Bc2Part" .. tostring(partIdx), "Model " .. curModel .. " HTTP " .. tostring(code) .. ": " .. tostring(M.extractApiError(content) or "Busy"))
                    local altKey = M.getAlternateApiKey(curKey)
                    if altKey and keyRetries < 4 then
                        M.delay(250, function() processBcPart(partIdx, ttsIdx, modeIdx, altKey, keyRetries + 1) end)
                        return
                    elseif ttsIdx < #ttsQueue then
                        M.delay(300, function() processBcPart(partIdx, ttsIdx + 1, 1, M.getNextApiKey(), 0) end)
                        return
                    end
                end

                if code == 200 then
                    local byteArrays = decodeAudioPartsFromResponse(content)
                    if #byteArrays == 0 then
                        stopOnError("Part " .. tostring(partIdx) .. " returned empty audio.")
                        return
                    end

                    local pf = M.getResumePartFile(partIdx)
                    local okSave, errSave = writePcmArraysToFile(pf, byteArrays)
                    if not okSave then
                        stopOnError("Part " .. tostring(partIdx) .. " save error: " .. tostring(errSave))
                        return
                    end

                    local donePct = math.max(5, math.floor((partIdx / totalParts) * 90))
                    M.updateProgress(donePct, "Broadcast Part " .. tostring(partIdx) .. "/" .. tostring(totalParts) .. " done", false)

                    if partIdx < totalParts then
                        M.delay(50, function() processBcPart(partIdx + 1, ttsIdx, modeIdx, M.getNextApiKey(), 0) end)
                    else
                        finishMerge()
                    end
                else
                    stopOnError("Part " .. tostring(partIdx) .. " error (" .. tostring(code) .. "): " .. tostring(M.extractApiError(content) or "Server error"))
                end
            end)
            if not okP then stopOnError("Request failed: " .. tostring(errP)) end
        end

        if startIdx > totalParts then
            finishMerge()
            return
        end
        local firstKey = M.getNextApiKey()
        if startIdx > 1 then
            M.updateProgress(math.max(5, math.floor(((startIdx - 1) / totalParts) * 90)),
                "Resuming broadcast from Part " .. tostring(startIdx) .. "/" .. tostring(totalParts) .. " (" .. tostring(startIdx - 1) .. " saved)...", true)
        else
            M.updateProgress(5, "Checking active audio models...", false)
        end
        M.discoverWorkingTtsModels(firstKey, primaryModel, function(discoveredQueue)
            if isCanceled() then return end
            if discoveredQueue and #discoveredQueue > 0 then
                ttsQueue = discoveredQueue
            end
            processBcPart(startIdx, 1, 1, firstKey, 0)
        end)
        return
    end

    -- PATH B: 3-to-6 Speakers Smart 2-Speaker Pair Batching Engine (4000 True Chars)
    local batches = M.parseGroupSpeakerBatches(cleanScript, spkCount)
    local totalParts = #batches
    if totalParts == 0 then
        stopOnError("Group script format not found. Tap CREATE SCRIPT first.")
        return
    end

    local audioSig = M.makeAudioSig(inputText, M.cfg.mode)
    local doneA, savedTotalA, firstMissingA = M.getAudioResumeStatus(inputText, M.cfg.mode)
    local startIdx = 1
    if savedTotalA == totalParts and doneA > 0 then
        startIdx = firstMissingA or (totalParts + 1)
    else
        M.clearAudioResume()
        M.saveAudioResumeMeta(audioSig, M.cfg.mode, totalParts)
        startIdx = 1
    end

    local function finishGroupMerge()
        if isCanceled() then return end
        local allFiles = {}
        for i = 1, totalParts do table.insert(allFiles, M.getResumePartFile(i)) end
        M.updateProgress(95, "Merging all " .. tostring(totalParts) .. " group broadcast parts...", false)
        local okM, durOrErr = M.mergePcmFilesToWav(allFiles, 240, "gemini_group_" .. tostring(spkCount) .. "spk")
        if isCanceled() then M.deleteOldAudioFile() return end
        if not okM then
            stopOnError("Merge error: " .. tostring(durOrErr))
            return
        end
        M.onAudioReadyUI(durOrErr, tostring(spkCount) .. "-Speaker Broadcast")
    end

    local function processBatch(partIdx, ttsIdx, modeIdx, curKey, keyRetries)
        if isCanceled() then return end
        local curModel = ttsQueue[ttsIdx]
        if not curModel then
            stopOnError("Failed at Part " .. tostring(partIdx) .. "/" .. tostring(totalParts) .. ". Check Report Issue.")
            return
        end

        local batch = batches[partIdx]
        local spkList = batch.speakers
        local isMulti = (#spkList >= 2)

        local pct = math.max(5, math.floor(((partIdx - 1) / totalParts) * 90))
        M.updateProgress(pct, "Broadcast Part " .. tostring(partIdx) .. "/" .. tostring(totalParts) .. " generating...", partIdx == 1 and modeIdx == 1 and keyRetries == 0)

        local contNote = ""
        if partIdx > 1 and batches[partIdx - 1] and #batches[partIdx - 1].turns > 0 then
            local prevBatchTurns = batches[partIdx - 1].turns
            local lastTurn = prevBatchTurns[#prevBatchTurns]
            contNote = ", continuing naturally right after '" .. string.sub(lastTurn.text or "", -160) .. "' with consistent pitch and tempo"
        end

        local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. curModel .. ":generateContent?key=" .. curKey
        local partsArray = {}
        local genCfg

        if isMulti then
            local idxA, idxB = spkList[1], spkList[2]
            local labelA, labelB = "Speaker" .. tostring(idxA), "Speaker" .. tostring(idxB)
            local voiceA = M.cfg.speakerVoices[idxA] or M.DEFAULT_SPK_VOICES[idxA] or "Puck"
            local voiceB = M.cfg.speakerVoices[idxB] or M.DEFAULT_SPK_VOICES[idxB] or "Kore"

            local styleA = "consistent broadcast friend (" .. voiceA .. ") speaking in " .. lang
                .. ", strictly matching exact mood: " .. mood .. ", locked to identical voice identity, vocal pitch, and steady tempo" .. contNote
            local styleB = "consistent broadcast friend (" .. voiceB .. ") speaking in " .. lang
                .. ", strictly matching exact mood: " .. mood .. ", locked to identical voice identity, vocal pitch, and steady tempo" .. contNote

            for _, turn in ipairs(batch.turns) do
                local lbl = "Speaker" .. tostring(turn.speakerIdx)
                local st = (turn.speakerIdx == idxA) and styleA or styleB
                if modeIdx <= 2 then
                    table.insert(partsArray, { text = turn.text, speech_metadata = { speaker = lbl, style = st } })
                elseif modeIdx == 3 then
                    table.insert(partsArray, { text = turn.text, speech_metadata = { speaker = lbl } })
                else
                    table.insert(partsArray, { text = turn.text, speechMetadata = { speaker = lbl } })
                end
            end

            local spkCfgs = (modeIdx <= 3) and {
                { speaker = labelA, voiceConfig = { voice = voiceA } },
                { speaker = labelB, voiceConfig = { voice = voiceB } }
            } or {
                { speaker = labelA, voiceConfig = { prebuiltVoiceConfig = { voiceName = voiceA } } },
                { speaker = labelB, voiceConfig = { prebuiltVoiceConfig = { voiceName = voiceB } } }
            }

            genCfg = {
                responseModalities = { "AUDIO" },
                speechConfig = { multiSpeakerVoiceConfig = { speakerVoiceConfigs = spkCfgs } }
            }
        else
            local idxA = spkList[1]
            local voiceA = M.cfg.speakerVoices[idxA] or M.DEFAULT_SPK_VOICES[idxA] or "Puck"
            local combinedText = {}
            for _, turn in ipairs(batch.turns) do
                table.insert(combinedText, turn.text)
            end
            local stylePrompt = "natural group podcast friend (" .. voiceA .. ") speaking in " .. lang
                .. ", strictly matching exact mood: " .. mood .. ", keeping identical voice identity, vocal pitch, and lively tone throughout" .. contNote
            local partObj = { text = table.concat(combinedText, " ") }
            if modeIdx == 3 then
                partObj.speechMetadata = { style = stylePrompt }
            else
                partObj.speech_metadata = { style = stylePrompt }
            end
            table.insert(partsArray, partObj)

            genCfg = {
                responseModalities = { "AUDIO" },
                speechConfig = { voiceConfig = { voice = voiceA } }
            }
        end

        if modeIdx == 1 then
            genCfg.temperature = 0.0
            genCfg.seed = 424242 + spkList[1]
        elseif modeIdx == 2 then
            genCfg.temperature = 0.05
            genCfg.seed = 424242 + spkList[1]
        end

        local payload = {
            contents = { { role = "user", parts = partsArray } },
            generationConfig = genCfg
        }

        local okP, errP = M.httpPost(url, cjson.encode(payload), headers, function(code, content)
            if isCanceled() then return end

            if code == 400 and modeIdx < 4 then
                M.delay(100, function() processBatch(partIdx, ttsIdx, modeIdx + 1, curKey, keyRetries) end)
                return
            end

            if code == 429 or code == 503 or code == 500 or code == -1 or code == 404 then
                M.logIssue("GroupPart" .. tostring(partIdx), "Model " .. curModel .. " HTTP " .. tostring(code) .. ": " .. tostring(M.extractApiError(content) or "Busy"))
                local altKey = M.getAlternateApiKey(curKey)
                if altKey and keyRetries < 4 then
                    M.delay(250, function() processBatch(partIdx, ttsIdx, modeIdx, altKey, keyRetries + 1) end)
                    return
                elseif ttsIdx < #ttsQueue then
                    M.delay(300, function() processBatch(partIdx, ttsIdx + 1, 1, M.getNextApiKey(), 0) end)
                    return
                end
            end

            if code == 200 then
                local byteArrays = decodeAudioPartsFromResponse(content)
                if #byteArrays == 0 then
                    stopOnError("Part " .. tostring(partIdx) .. " returned empty audio.")
                    return
                end

                local pf = M.getResumePartFile(partIdx)
                local okSave, errSave = writePcmArraysToFile(pf, byteArrays)
                if not okSave then
                    stopOnError("Part " .. tostring(partIdx) .. " save error: " .. tostring(errSave))
                    return
                end

                local donePct = math.max(5, math.floor((partIdx / totalParts) * 90))
                M.updateProgress(donePct, "Broadcast Part " .. tostring(partIdx) .. "/" .. tostring(totalParts) .. " done", false)

                if partIdx < totalParts then
                    M.delay(50, function() processBatch(partIdx + 1, ttsIdx, modeIdx, M.getNextApiKey(), 0) end)
                else
                    finishGroupMerge()
                end
            else
                stopOnError("Part " .. tostring(partIdx) .. " error (" .. tostring(code) .. "): " .. tostring(M.extractApiError(content) or "Server error"))
            end
        end)
        if not okP then stopOnError("Request failed: " .. tostring(errP)) end
    end

    if startIdx > totalParts then
        finishGroupMerge()
        return
    end
    local firstKey = M.getNextApiKey()
    if startIdx > 1 then
        M.updateProgress(math.max(5, math.floor(((startIdx - 1) / totalParts) * 90)),
            "Resuming broadcast from Part " .. tostring(startIdx) .. "/" .. tostring(totalParts) .. " (" .. tostring(startIdx - 1) .. " saved)...", true)
    else
        M.updateProgress(5, "Checking active audio models...", false)
    end
    M.discoverWorkingTtsModels(firstKey, primaryModel, function(discoveredQueue)
        if isCanceled() then return end
        if discoveredQueue and #discoveredQueue > 0 then
            ttsQueue = discoveredQueue
        end
        processBatch(startIdx, 1, 1, firstKey, 0)
    end)
end
-- ============================================================
-- PART 3 OF 3: Picker Dialogs, Voice Preview Dialog, 5-Key Settings,
--              Share, Download & Clean Button Main UI (Launch v4)
-- ============================================================

-- ============================================================
-- Stream Copy & File Name Sanitizer Helpers
-- ============================================================
local function copyStream(input, output)
    local buffer = byte[32768]
    while true do
        local len = input.read(buffer)
        if len == nil or len == -1 then break end
        output.write(buffer, 0, len)
    end
end

local function makeSafeFileName(rawName)
    local s = M.trim(rawName or "")
    s = s:gsub("%.wav$", ""):gsub("%.WAV$", "")
    s = s:gsub("[^%w%-%_ ]", ""):gsub("%s+", "_")
    s = s:gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
    if #s > 45 then s = string.sub(s, 1, 45) end
    if s == "" then s = "Gemini_Audio_" .. os.date("%H%M%S") end
    return s
end

local function getDefaultDownloadName()
    local sc = M.getModeSpeakerCount(M.cfg.mode)
    local isSingle = (sc == 1)
    local prefix = isSingle and "Single_" or ("Broadcast_" .. tostring(sc) .. "Spk_")
    local moodOrStyle = isSingle and M.cfg.singleStyle or M.cfg.bcMood
    local cleanTag = tostring(moodOrStyle or "Audio"):gsub("[^%w ]", ""):gsub("%s+", "_")
    if #cleanTag > 20 then cleanTag = string.sub(cleanTag, 1, 20) end
    cleanTag = cleanTag:gsub("_$", "")
    return prefix .. cleanTag .. "_" .. os.date("%H%M%S")
end

-- ============================================================
-- Smooth Scrollable List Picker Dialog (No Scroll-Exit Bug)
-- ============================================================
function M.showListPickerDialog(title, displayList, valueList, currentVal, onSelect)
    local vals = valueList or displayList
    local shownItems = {}
    local selIdx = 0
    for i, item in ipairs(displayList) do
        if vals[i] == currentVal then
            table.insert(shownItems, "[✓] " .. item)
            selIdx = i - 1
        else
            table.insert(shownItems, item)
        end
    end

    local views = {}
    local layout = {
        LinearLayout,
        orientation = "vertical",
        padding = "14dp",
        layout_width = "fill",
        layout_height = "wrap",
        {
            ListView,
            id = "pickerList",
            layout_width = "fill",
            layout_height = "340dp",
            backgroundColor = "#F5F5F5",
            layout_marginBottom = "10dp"
        },
        {
            Button,
            id = "backBtn",
            text = "GO BACK",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#9E9E9E",
            textColor = "#FFFFFF",
            padding = "11dp"
        }
    }

    local dlg = LuaDialog(context)
    dlg.setTitle(title)
    dlg.setView(loadlayout(layout, views))
    dlg.setCancelable(true)

    local adapter = ArrayAdapter(context, android.R.layout.simple_list_item_1, shownItems)
    views.pickerList.setAdapter(adapter)
    pcall(function() views.pickerList.setSelection(selIdx) end)

    views.pickerList.onItemClick = function(parent, v, pos, id)
        local chosen = vals[pos + 1]
        if chosen then
            dlg.dismiss()
            if onSelect then onSelect(chosen) end
        end
    end

    views.backBtn.onClick = function() dlg.dismiss() end
    dlg.show()
end

-- ============================================================
-- Voice Selector Dialog (Stay on List + [✓] + 3-5s Preview + DONE)
-- ============================================================
function M.showVoicePickerDialog(title, currentRawVoice, onConfirm)
    local tempVoice = currentRawVoice or "Puck"
    local views = {}
    local layout = {
        LinearLayout,
        orientation = "vertical",
        padding = "14dp",
        layout_width = "fill",
        layout_height = "wrap",
        {
            ListView,
            id = "voiceList",
            layout_width = "fill",
            layout_height = "340dp",
            backgroundColor = "#F5F5F5",
            layout_marginBottom = "10dp"
        },
        {
            Button,
            id = "doneBtn",
            text = "DONE",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#2E7D32",
            textColor = "#FFFFFF",
            padding = "12dp"
        }
    }

    local dlg = LuaDialog(context)
    dlg.setTitle(title)
    dlg.setView(loadlayout(layout, views))
    dlg.setCancelable(true)

    local function buildDisplay()
        local items = {}
        local selIdx = 0
        for i, disp in ipairs(M.VOICE_LIST) do
            if M.RAW_VOICES[i] == tempVoice then
                table.insert(items, "[✓] " .. disp)
                selIdx = i - 1
            else
                table.insert(items, disp)
            end
        end
        return items, selIdx
    end

    local items, selIdx = buildDisplay()
    local adapter = ArrayAdapter(context, android.R.layout.simple_list_item_1, items)
    views.voiceList.setAdapter(adapter)
    pcall(function() views.voiceList.setSelection(selIdx) end)

    views.voiceList.onItemClick = function(parent, v, pos, id)
        local pickedRaw = M.RAW_VOICES[pos + 1]
        if not pickedRaw then return end
        tempVoice = pickedRaw

        -- Refresh checkmarks without closing dialog or losing scroll position
        local firstVis = views.voiceList.getFirstVisiblePosition()
        local newItems = buildDisplay()
        local newAdapter = ArrayAdapter(context, android.R.layout.simple_list_item_1, newItems)
        views.voiceList.setAdapter(newAdapter)
        pcall(function() views.voiceList.setSelection(firstVis) end)

        -- Play 3-5 second cached voice sample
        M.previewVoiceSample(pickedRaw)
    end

    views.doneBtn.onClick = function()
        M.stopPreviewPlayer()
        dlg.dismiss()
        if onConfirm then onConfirm(tempVoice) end
    end

    dlg.show()
end

-- ============================================================
-- Share Audio (Auto-Closes Overlay First So Share Menu Opens Immediately)
-- ============================================================
function M.shareAudio()
    if not S.generatedAudioPath then
        M.speakOnly("Please generate audio first.")
        return
    end

    local sourceFile = File(S.generatedAudioPath)
    if not sourceFile.exists() then
        M.speakOnly("Audio file not found.")
        return
    end

    local fileName = getDefaultDownloadName() .. ".wav"
    local shareUri = nil
    local lastErr = ""

    if Build.VERSION.SDK_INT >= 29 then
        local ok, err = pcall(function()
            local input = FileInputStream(sourceFile)
            local values = ContentValues()
            values.put("_display_name", fileName)
            values.put("mime_type", "audio/wav")
            values.put("relative_path", Environment.DIRECTORY_DOWNLOADS)
            local resolver = context.getContentResolver()
            local DownloadsClass = luajava.bindClass("android.provider.MediaStore$Downloads")
            local uri = resolver.insert(DownloadsClass.EXTERNAL_CONTENT_URI, values)
            local output = resolver.openOutputStream(uri)
            copyStream(input, output)
            output.flush()
            output.close()
            input.close()
            shareUri = uri
        end)
        if not ok then lastErr = tostring(err) end
    end

    if not shareUri then
        local ok, err = pcall(function()
            local downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if not downloadDir.exists() then downloadDir.mkdirs() end
            local destFile = File(downloadDir, fileName)
            local input = FileInputStream(sourceFile)
            local output = FileOutputStream(destFile)
            copyStream(input, output)
            output.flush()
            output.close()
            input.close()
            shareUri = Uri.fromFile(destFile)
        end)
        if not ok then lastErr = lastErr .. " | " .. tostring(err) end
    end

    if not shareUri then
        M.logIssue("ShareAudio", lastErr)
        M.speakOnly("Could not prepare audio for sharing: " .. lastErr)
        return
    end

    M.stopPreviewPlayer()
    if M.mainDialogRef then
        pcall(function()
            if S.ui and S.ui.textInput then
                M.saveDraftText(S.ui.textInput.getText().toString())
            end
            S.ui = nil
            M.mainDialogRef.dismiss()
            M.mainDialogRef = nil
        end)
    end

    M.speakOnly("Opening share menu.")
    M.delay(200, function()
        local okIntent, errIntent = pcall(function()
            local sendIntent = Intent(Intent.ACTION_SEND)
            sendIntent.setType("audio/wav")
            sendIntent.putExtra(Intent.EXTRA_STREAM, shareUri)
            sendIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            local chooser = Intent.createChooser(sendIntent, "Share Audio via")
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(chooser)
        end)
        if not okIntent then
            M.logIssue("ShareIntent", tostring(errIntent))
            M.speakOnly("Share failed: " .. tostring(errIntent))
        end
    end)
end

-- ============================================================
-- Download System (Custom File Name Dialog & Auto-Clear)
-- ============================================================
function M.performDownload(customBaseName)
    if not S.generatedAudioPath then
        M.speakOnly("Please generate audio first.")
        return false
    end

    local sourceFile = File(S.generatedAudioPath)
    if not sourceFile.exists() then
        M.speakOnly("Audio file not found.")
        return false
    end

    local safeBase = makeSafeFileName(customBaseName)
    local fileName = safeBase .. ".wav"
    local success = false
    local lastErr = ""

    if Build.VERSION.SDK_INT >= 29 then
        local ok, err = pcall(function()
            local input = FileInputStream(sourceFile)
            local values = ContentValues()
            values.put("_display_name", fileName)
            values.put("mime_type", "audio/x-wav")
            values.put("relative_path", Environment.DIRECTORY_DOWNLOADS)
            local resolver = context.getContentResolver()
            local DownloadsClass = luajava.bindClass("android.provider.MediaStore$Downloads")
            local uri = resolver.insert(DownloadsClass.EXTERNAL_CONTENT_URI, values)
            local output = resolver.openOutputStream(uri)
            copyStream(input, output)
            output.flush()
            output.close()
            input.close()
        end)
        if ok then success = true else lastErr = tostring(err) end
    end

    if not success then
        local ok, err = pcall(function()
            local downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if not downloadDir.exists() then downloadDir.mkdirs() end
            local destFile = File(downloadDir, fileName)
            local input = FileInputStream(sourceFile)
            local output = FileOutputStream(destFile)
            copyStream(input, output)
            output.flush()
            output.close()
            input.close()
            pcall(function()
                local intent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
                intent.setData(Uri.fromFile(destFile))
                context.sendBroadcast(intent)
            end)
        end)
        if ok then success = true else lastErr = lastErr .. " | " .. tostring(err) end
    end

    if success then
        M.clearIssueReport()
        M.clearAudioResume()
        M.clearScriptResume()
        M.clearLastWavPrefs()
        M.deleteOldAudioFile()
        M.cfg.userText = ""
        M.saveDraftText("")
        M.runOnUi(function()
            if S.ui then
                M.isUiInitializing = true
                if S.ui.textInput then S.ui.textInput.setText("") end
                if S.ui.charCounter then S.ui.charCounter.setText("0 chars (Unlimited)") end
                if S.ui.resultLayout then S.ui.resultLayout.setVisibility(View.GONE) end
                if S.ui.playBtn then
                    S.ui.playBtn.setEnabled(false)
                    S.ui.playBtn.setText("PLAY")
                end
                M.isUiInitializing = false
            end
        end)
        M.refreshActionButtons()
        M.updateProgress(0, "Saved as " .. fileName .. "! Saved parts and box cleared.", true)
        return true
    else
        M.logIssue("Download", lastErr)
        M.speakOnly("Download failed: " .. lastErr)
        return false
    end
end

function M.showDownloadDialog()
    if not S.generatedAudioPath or not File(S.generatedAudioPath).exists() then
        M.speakOnly("Please generate audio first.")
        return
    end

    local defaultName = getDefaultDownloadName()
    local views = {}
    local layout = {
        LinearLayout,
        orientation = "vertical",
        padding = "20dp",
        layout_width = "fill",
        layout_height = "wrap",
        {
            TextView,
            text = "Enter file name (or tap SAVE for default):",
            textSize = 14,
            textColor = "#333333",
            paddingBottom = "8dp"
        },
        {
            EditText,
            id = "fileNameInput",
            hint = "Enter file name...",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#F5F5F5",
            padding = "10dp",
            textSize = 14,
            singleLine = true,
            layout_marginBottom = "14dp"
        },
        {
            Button,
            id = "saveFileBtn",
            text = "SAVE",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#2E7D32",
            textColor = "#FFFFFF",
            padding = "12dp",
            layout_marginBottom = "10dp"
        },
        {
            Button,
            id = "cancelBtn",
            text = "GO BACK",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#9E9E9E",
            textColor = "#FFFFFF",
            padding = "12dp"
        }
    }

    local dlDialog = LuaDialog(context)
    dlDialog.setTitle("Save Audio")
    dlDialog.setView(loadlayout(layout, views))
    dlDialog.setCancelable(true)

    views.fileNameInput.setText(defaultName)

    views.saveFileBtn.onClick = M.safe("saveFile", function()
        local entered = M.trim(views.fileNameInput.getText().toString())
        if entered == "" then entered = defaultName end
        dlDialog.dismiss()
        M.performDownload(entered)
    end)

    views.cancelBtn.onClick = function() dlDialog.dismiss() end

    dlDialog.show()
    M.speakOnly("Enter file name or tap Save.")
end

-- ============================================================
-- Dialog: Report Issue
-- ============================================================
function M.showReportIssueDialog()
    local views = {}
    local reportText = M.getIssueReport()
    local hasReport = (reportText ~= nil and M.trim(reportText) ~= "")
    local displayReport = hasReport and reportText or "No errors or issues recorded yet. Everything is working smoothly."

    local layout = {
        LinearLayout,
        orientation = "vertical",
        padding = "18dp",
        layout_width = "fill",
        layout_height = "wrap",
        {
            ScrollView,
            layout_width = "fill",
            layout_height = "240dp",
            backgroundColor = "#F5F5F5",
            layout_marginBottom = "12dp",
            {
                TextView,
                id = "reportTv",
                text = displayReport,
                textSize = 13,
                textColor = "#222222",
                padding = "10dp"
            }
        },
        {
            Button,
            id = "copyRepBtn",
            text = "COPY REPORT",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#0277BD",
            textColor = "#FFFFFF",
            padding = "11dp",
            layout_marginBottom = "8dp"
        },
        {
            Button,
            id = "sendWaRepBtn",
            text = "SEND ON WHATSAPP",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#2E7D32",
            textColor = "#FFFFFF",
            padding = "11dp",
            layout_marginBottom = "8dp"
        },
        {
            Button,
            id = "clearRepBtn",
            text = "CLEAR LOG",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#D84315",
            textColor = "#FFFFFF",
            padding = "11dp",
            layout_marginBottom = "8dp"
        },
        {
            Button,
            id = "backBtn",
            text = "GO BACK",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#9E9E9E",
            textColor = "#FFFFFF",
            padding = "11dp"
        }
    }

    local repDialog = LuaDialog(context)
    repDialog.setTitle("Report Issue")
    repDialog.setView(loadlayout(layout, views))
    repDialog.setCancelable(true)

    views.copyRepBtn.onClick = M.safe("copyReport", function()
        local cur = M.getIssueReport()
        if cur == "" then M.speakOnly("No error report to copy.") return end
        local cm = context.getSystemService(Context.CLIPBOARD_SERVICE)
        cm.setPrimaryClip(ClipData.newPlainText("Issue Report", cur))
        M.speakOnly("Issue report copied to clipboard.")
    end)

    views.sendWaRepBtn.onClick = M.safe("sendWaReport", function()
        local cur = M.getIssueReport()
        if cur == "" then M.speakOnly("No error report to send.") return end
        local msg = M.APP_TITLE .. " Issue Report:\n" .. string.sub(cur, -1500)
        local encoded = Uri.encode(msg)
        local intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/" .. M.WHATSAPP_INTL .. "?text=" .. encoded))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        M.speakOnly("Opening WhatsApp to send report.")
    end)

    views.clearRepBtn.onClick = M.safe("clearReport", function()
        M.clearIssueReport()
        views.reportTv.setText("No errors or issues recorded yet. Everything is working smoothly.")
        M.speakOnly("Issue log cleared.")
    end)

    views.backBtn.onClick = function() repDialog.dismiss() end
    repDialog.show()
end

-- ============================================================
-- Dialogs: About & Support, Guide, 5 API Keys, Settings
-- ============================================================
function M.showAboutDialog()
    local views = {}
    local layout = {
        LinearLayout,
        orientation = "vertical",
        padding = "20dp",
        layout_width = "fill",
        layout_height = "wrap",
        {
            TextView,
            text = M.APP_TITLE,
            textSize = 18,
            textColor = "#2E7D32",
            gravity = "center",
            typeface = Typeface.DEFAULT_BOLD,
            paddingBottom = "10dp"
        },
        {
            TextView,
            text = "Created By: " .. M.CREATOR_NAME,
            textSize = 15,
            textColor = "#222222",
            paddingBottom = "6dp"
        },
        {
            TextView,
            text = "WhatsApp: " .. M.WHATSAPP_LOCAL,
            textSize = 15,
            textColor = "#1565C0",
            paddingBottom = "16dp"
        },
        {
            Button,
            id = "copyWaBtn",
            text = "COPY WHATSAPP",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#0277BD",
            textColor = "#FFFFFF",
            padding = "12dp",
            layout_marginBottom = "10dp"
        },
        {
            Button,
            id = "contactWaBtn",
            text = "CONTACT WHATSAPP",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#2E7D32",
            textColor = "#FFFFFF",
            padding = "12dp",
            layout_marginBottom = "10dp"
        },
        {
            Button,
            id = "backBtn",
            text = "GO BACK",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#9E9E9E",
            textColor = "#FFFFFF",
            padding = "12dp"
        }
    }

    local aboutDialog = LuaDialog(context)
    aboutDialog.setTitle("About & Support")
    aboutDialog.setView(loadlayout(layout, views))
    aboutDialog.setCancelable(true)

    views.copyWaBtn.onClick = M.safe("copyWa", function()
        local cm = context.getSystemService(Context.CLIPBOARD_SERVICE)
        cm.setPrimaryClip(ClipData.newPlainText("WhatsApp", M.WHATSAPP_LOCAL))
        M.speakOnly("WhatsApp number " .. M.WHATSAPP_LOCAL .. " copied.")
    end)

    views.contactWaBtn.onClick = M.safe("contactWa", function()
        local intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/" .. M.WHATSAPP_INTL))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        M.speakOnly("Opening WhatsApp chat.")
    end)

    views.backBtn.onClick = function() aboutDialog.dismiss() end
    aboutDialog.show()
end

function M.showGuideDialog()
    local views = {}
    local layout = {
        LinearLayout,
        orientation = "vertical",
        padding = "18dp",
        layout_width = "fill",
        layout_height = "wrap",
        {
            ScrollView,
            layout_width = "fill",
            layout_height = "340dp",
            layout_marginBottom = "14dp",
            {
                TextView,
                text = M.USER_GUIDE_TEXT,
                textSize = 14,
                textColor = "#222222",
                padding = "6dp"
            }
        },
        {
            Button,
            id = "backBtn",
            text = "GO BACK",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#9E9E9E",
            textColor = "#FFFFFF",
            padding = "12dp"
        }
    }

    local guideDialog = LuaDialog(context)
    guideDialog.setTitle("Description / User Guide")
    guideDialog.setView(loadlayout(layout, views))
    guideDialog.setCancelable(true)

    views.backBtn.onClick = function() guideDialog.dismiss() end
    guideDialog.show()
end

function M.showSetApiDialog()
    local views = {}
    local layout = {
        ScrollView,
        layout_width = "fill",
        layout_height = "wrap",
        {
            LinearLayout,
            orientation = "vertical",
            padding = "16dp",
            layout_width = "fill",
            layout_height = "wrap",
            {
                EditText,
                id = "apiInput1",
                hint = "API Key 1 (Primary)",
                layout_width = "fill",
                layout_height = "wrap",
                backgroundColor = "#F5F5F5",
                padding = "9dp",
                textSize = 13,
                singleLine = true,
                layout_marginBottom = "8dp"
            },
            {
                EditText,
                id = "apiInput2",
                hint = "API Key 2 (Auto-Failover)",
                layout_width = "fill",
                layout_height = "wrap",
                backgroundColor = "#F5F5F5",
                padding = "9dp",
                textSize = 13,
                singleLine = true,
                layout_marginBottom = "8dp"
            },
            {
                EditText,
                id = "apiInput3",
                hint = "API Key 3 (Auto-Failover)",
                layout_width = "fill",
                layout_height = "wrap",
                backgroundColor = "#F5F5F5",
                padding = "9dp",
                textSize = 13,
                singleLine = true,
                layout_marginBottom = "8dp"
            },
            {
                EditText,
                id = "apiInput4",
                hint = "API Key 4 (Auto-Failover)",
                layout_width = "fill",
                layout_height = "wrap",
                backgroundColor = "#F5F5F5",
                padding = "9dp",
                textSize = 13,
                singleLine = true,
                layout_marginBottom = "8dp"
            },
            {
                EditText,
                id = "apiInput5",
                hint = "API Key 5 (Auto-Failover)",
                layout_width = "fill",
                layout_height = "wrap",
                backgroundColor = "#F5F5F5",
                padding = "9dp",
                textSize = 13,
                singleLine = true,
                layout_marginBottom = "12dp"
            },
            {
                Button,
                id = "testBtn",
                text = "TEST ACTIVE KEYS",
                layout_width = "fill",
                layout_height = "wrap",
                backgroundColor = "#FF9800",
                textColor = "#FFFFFF",
                padding = "11dp",
                layout_marginBottom = "8dp"
            },
            {
                Button,
                id = "saveBtn",
                text = "SAVE API KEYS",
                layout_width = "fill",
                layout_height = "wrap",
                backgroundColor = "#4CAF50",
                textColor = "#FFFFFF",
                padding = "11dp",
                layout_marginBottom = "8dp"
            },
            {
                Button,
                id = "backBtn",
                text = "GO BACK",
                layout_width = "fill",
                layout_height = "wrap",
                backgroundColor = "#9E9E9E",
                textColor = "#FFFFFF",
                padding = "11dp"
            }
        }
    }

    local apiDialog = LuaDialog(context)
    apiDialog.setTitle("Set API Keys (1-5)")
    apiDialog.setView(loadlayout(layout, views))
    apiDialog.setCancelable(true)

    for i = 1, 5 do
        views["apiInput" .. i].setText(M.cfg.apiKeys[i] or "")
    end

    views.testBtn.onClick = M.safe("testApi", function()
        local toTest = {}
        for i = 1, 5 do
            local k = M.sanitizeKey(views["apiInput" .. i].getText().toString())
            views["apiInput" .. i].setText(k)
            if k ~= "" then table.insert(toTest, { idx = i, key = k }) end
        end
        if #toTest == 0 then
            M.speakOnly("Please paste at least one API key first.")
            return
        end

        views.testBtn.setText("TESTING...")
        views.testBtn.setEnabled(false)
        M.speakOnly("Testing " .. tostring(#toTest) .. " API key(s).")

        local results = {}
        local function testNext(n)
            if n > #toTest then
                M.runOnUi(function()
                    views.testBtn.setText("TEST ACTIVE KEYS")
                    views.testBtn.setEnabled(true)
                    M.speakOnly(table.concat(results, ". "))
                end)
                return
            end
            local item = toTest[n]
            local url = "https://generativelanguage.googleapis.com/v1beta/models?key=" .. item.key
            M.httpGet(url, function(code, content)
                if code == 200 then
                    table.insert(results, "Key " .. item.idx .. " is active")
                else
                    M.logIssue("TestApiKey" .. item.idx, "HTTP " .. tostring(code))
                    table.insert(results, "Key " .. item.idx .. " failed code " .. tostring(code))
                end
                testNext(n + 1)
            end)
        end
        testNext(1)
    end)

    views.saveBtn.onClick = M.safe("saveApi", function()
        local newKeys, activeCnt = {}, 0
        for i = 1, 5 do
            local k = M.sanitizeKey(views["apiInput" .. i].getText().toString())
            newKeys[i] = k
            if k ~= "" then activeCnt = activeCnt + 1 end
        end
        if activeCnt == 0 then
            M.speakOnly("Please enter at least one API key.")
            return
        end
        M.cfg.apiKeys = newKeys
        M.cachedScriptModels = nil
        M.cachedTtsModels = nil
        M.saveSettings()
        M.speakOnly(tostring(activeCnt) .. " API key(s) saved.")
        apiDialog.dismiss()
    end)

    views.backBtn.onClick = function() apiDialog.dismiss() end
    apiDialog.show()
end

function M.showSettingsDialog()
    local views = {}
    local layout = {
        LinearLayout,
        orientation = "vertical",
        padding = "20dp",
        layout_width = "fill",
        layout_height = "wrap",
        {
            Button,
            id = "setApiBtn",
            text = "SET API KEYS (1-5)",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#2196F3",
            textColor = "#FFFFFF",
            padding = "12dp",
            layout_marginBottom = "10dp"
        },
        {
            Button,
            id = "modelBtn",
            text = "Audio Model: " .. tostring(M.cfg.model),
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#37474F",
            textColor = "#FFFFFF",
            padding = "12dp",
            layout_marginBottom = "10dp"
        },
        {
            Button,
            id = "guideBtn",
            text = "DESCRIPTION / GUIDE",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#00897B",
            textColor = "#FFFFFF",
            padding = "12dp",
            layout_marginBottom = "10dp"
        },
        {
            Button,
            id = "reportBtn",
            text = "REPORT ISSUE",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#E65100",
            textColor = "#FFFFFF",
            padding = "12dp",
            layout_marginBottom = "10dp"
        },
        {
            Button,
            id = "aboutBtn",
            text = "ABOUT & SUPPORT",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#5E35B1",
            textColor = "#FFFFFF",
            padding = "12dp",
            layout_marginBottom = "12dp"
        },
        {
            Button,
            id = "goBackBtn",
            text = "GO BACK",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#9E9E9E",
            textColor = "#FFFFFF",
            padding = "12dp"
        }
    }

    local settingDialog = LuaDialog(context)
    settingDialog.setTitle("Settings")
    settingDialog.setView(loadlayout(layout, views))
    settingDialog.setCancelable(true)

    views.setApiBtn.onClick = M.safe("setApi", function() M.showSetApiDialog() end)
    views.modelBtn.onClick = M.safe("modelPick", function()
        local pickList, seenM = {}, {}
        local function addOpt(m)
            if m and m ~= "" and not seenM[m] then seenM[m] = true table.insert(pickList, m) end
        end
        if M.cachedTtsModels then for _, m in ipairs(M.cachedTtsModels) do addOpt(m) end end
        for _, m in ipairs(M.MODEL_LIST) do addOpt(m) end
        M.showListPickerDialog("Select Audio Model", pickList, nil, M.cfg.model, function(chosen)
            M.cfg.model = chosen
            M.saveSettings()
            views.modelBtn.setText("Audio Model: " .. chosen)
            M.speakOnly("Model selected: " .. chosen)
        end)
    end)
    views.guideBtn.onClick = M.safe("guide", function() M.showGuideDialog() end)
    views.reportBtn.onClick = M.safe("report", function() M.showReportIssueDialog() end)
    views.aboutBtn.onClick = M.safe("about", function() M.showAboutDialog() end)
    views.goBackBtn.onClick = function() settingDialog.dismiss() end
    settingDialog.show()
end

-- ============================================================
-- Helper: Build 1 Speaker Row (Clean Optional Name + Voice Button)
-- ============================================================
local function makeSpeakerRowLayout(idx)
    return {
        LinearLayout,
        id = "spkRow_" .. idx,
        orientation = "vertical",
        layout_width = "fill",
        layout_height = "wrap",
        layout_marginBottom = "6dp",
        {
            EditText,
            id = "spkName_" .. idx,
            hint = "Speaker " .. idx .. " Name (Optional)",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#F5F5F5",
            padding = "8dp",
            textSize = 13,
            singleLine = true,
            layout_marginBottom = "4dp"
        },
        {
            Button,
            id = "spkVoiceBtn_" .. idx,
            text = "Speaker " .. idx .. " Voice: Puck (Male)",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#E8EAF6",
            textColor = "#1A237E",
            textSize = 13,
            padding = "9dp"
        }
    }
end

-- ============================================================
-- Main Screen (Clean Direct Buttons, No Extra Headings, No Copy Button)
-- ============================================================
function M.showMain()
    M.isUiInitializing = true
    M.loadSettings()

    local views = {}
    local mainLayout = {
        LinearLayout,
        orientation = "vertical",
        layout_width = "fill",
        layout_height = "fill",
        {
            ScrollView,
            layout_width = "fill",
            layout_height = "0dp",
            layout_weight = "1",
            {
                LinearLayout,
                orientation = "vertical",
                padding = "14dp",
                layout_width = "fill",
                layout_height = "wrap",
                {
                    TextView,
                    text = M.APP_TITLE,
                    textSize = 19,
                    textColor = "#2E7D32",
                    gravity = "center",
                    paddingBottom = "10dp",
                    typeface = Typeface.DEFAULT_BOLD
                },

                -- MODE BUTTON (1-6 Speakers)
                {
                    Button,
                    id = "modeBtn",
                    text = "Mode: Single Speaker (TTS & Story)",
                    layout_width = "fill",
                    layout_height = "wrap",
                    backgroundColor = "#E3F2FD",
                    textColor = "#0D47A1",
                    textSize = 13,
                    padding = "10dp",
                    layout_marginBottom = "8dp"
                },

                -- SINGLE SPEAKER OPTIONS
                {
                    LinearLayout,
                    id = "singleOptionsLayout",
                    orientation = "vertical",
                    layout_width = "fill",
                    layout_height = "wrap",
                    {
                        Button,
                        id = "singleVoiceBtn",
                        text = "Voice: Puck (Male)",
                        layout_width = "fill",
                        layout_height = "wrap",
                        backgroundColor = "#F3E5F5",
                        textColor = "#4A148C",
                        textSize = 13,
                        padding = "10dp",
                        layout_marginBottom = "8dp"
                    },
                    {
                        Button,
                        id = "singleStyleBtn",
                        text = "Mood / Style: Default / Normal",
                        layout_width = "fill",
                        layout_height = "wrap",
                        backgroundColor = "#F5F5F5",
                        textColor = "#222222",
                        textSize = 13,
                        padding = "10dp",
                        layout_marginBottom = "8dp"
                    }
                },

                -- MULTI-SPEAKER BROADCAST OPTIONS (Rows 1 to 6 Dynamically Shown)
                {
                    LinearLayout,
                    id = "bcOptionsLayout",
                    orientation = "vertical",
                    layout_width = "fill",
                    layout_height = "wrap",
                    visibility = View.GONE,
                    makeSpeakerRowLayout(1),
                    makeSpeakerRowLayout(2),
                    makeSpeakerRowLayout(3),
                    makeSpeakerRowLayout(4),
                    makeSpeakerRowLayout(5),
                    makeSpeakerRowLayout(6),
                    {
                        Button,
                        id = "bcMoodBtn",
                        text = "Broadcast Mood: Default / Normal",
                        layout_width = "fill",
                        layout_height = "wrap",
                        backgroundColor = "#F5F5F5",
                        textColor = "#222222",
                        textSize = 13,
                        padding = "10dp",
                        layout_marginBottom = "8dp"
                    }
                },

                -- LANGUAGE & DURATION BUTTONS
                {
                    Button,
                    id = "langBtn",
                    text = "Language: Urdu (Pakistan - اردو)",
                    layout_width = "fill",
                    layout_height = "wrap",
                    backgroundColor = "#E8F5E9",
                    textColor = "#1B5E20",
                    textSize = 13,
                    padding = "10dp",
                    layout_marginBottom = "8dp"
                },
                {
                    Button,
                    id = "durationBtn",
                    text = "Duration: 1 Minute",
                    layout_width = "fill",
                    layout_height = "wrap",
                    backgroundColor = "#FFF3E0",
                    textColor = "#E65100",
                    textSize = 13,
                    padding = "10dp",
                    layout_marginBottom = "8dp"
                },
                {
                    EditText,
                    id = "customMinInput",
                    hint = "Custom Minutes (e.g. 5, 30, 60)",
                    layout_width = "fill",
                    layout_height = "wrap",
                    backgroundColor = "#F5F5F5",
                    padding = "9dp",
                    textSize = 14,
                    singleLine = true,
                    visibility = View.GONE,
                    layout_marginBottom = "8dp"
                },

                -- UNLIMITED TOPIC / SCRIPT EDITBOX
                {
                    EditText,
                    id = "textInput",
                    hint = "Enter topic to CREATE SCRIPT, or paste unlimited text/script to GENERATE AUDIO...",
                    layout_width = "fill",
                    layout_height = "150dp",
                    backgroundColor = "#F5F5F5",
                    padding = "12dp",
                    gravity = Gravity.TOP,
                    textSize = 14,
                    layout_marginBottom = "6dp"
                },
                {
                    Button,
                    id = "clearTextBtn",
                    text = "CLEAR TEXT",
                    layout_width = "fill",
                    layout_height = "wrap",
                    backgroundColor = "#78909C",
                    textColor = "#FFFFFF",
                    textSize = 12,
                    padding = "8dp",
                    layout_marginBottom = "4dp"
                },
                {
                    TextView,
                    id = "charCounter",
                    text = "0 chars (Unlimited)",
                    layout_width = "fill",
                    textSize = 12,
                    textColor = "#888888",
                    gravity = "right",
                    paddingBottom = "4dp"
                }
            }
        },

        -- FIXED BOTTOM CONTROLS (Focus lands on statusText)
        {
            LinearLayout,
            orientation = "vertical",
            layout_width = "fill",
            layout_height = "wrap",
            paddingLeft = "14dp",
            paddingRight = "14dp",
            paddingTop = "6dp",
            paddingBottom = "14dp",
            {
                TextView,
                id = "statusText",
                text = "[0%] Status: Ready",
                layout_width = "fill",
                layout_height = "wrap",
                textSize = 13,
                textColor = "#1565C0",
                paddingBottom = "6dp",
                focusable = true,
                focusableInTouchMode = true,
                typeface = Typeface.DEFAULT_BOLD
            },
            {
                Button,
                id = "createScriptBtn",
                text = "CREATE SCRIPT",
                layout_width = "fill",
                layout_height = "wrap",
                backgroundColor = "#6A1B9A",
                textColor = "#FFFFFF",
                padding = "10dp",
                textSize = 14,
                layout_marginBottom = "6dp"
            },
            {
                Button,
                id = "generateBtn",
                text = "GENERATE AUDIO",
                layout_width = "fill",
                layout_height = "wrap",
                backgroundColor = "#2196F3",
                textColor = "#FFFFFF",
                padding = "10dp",
                textSize = 14,
                layout_marginBottom = "6dp"
            },
            {
                LinearLayout,
                id = "resultLayout",
                orientation = "vertical",
                layout_width = "fill",
                layout_height = "wrap",
                visibility = View.GONE,
                layout_marginBottom = "6dp",
                {
                    TextView,
                    id = "durationLabel",
                    text = "Audio Length: 0 min 00 sec",
                    textSize = 14,
                    textColor = "#1B5E20",
                    gravity = "center",
                    paddingBottom = "4dp",
                    typeface = Typeface.DEFAULT_BOLD
                },
                {
                    LinearLayout,
                    orientation = "horizontal",
                    layout_width = "fill",
                    layout_height = "wrap",
                    {
                        Button,
                        id = "playBtnID",
                        text = "PLAY",
                        layout_width = "0dp",
                        layout_weight = "1.2",
                        backgroundColor = "#4CAF50",
                        textColor = "#FFFFFF",
                        padding = "10dp",
                        layout_marginRight = "4dp",
                        enabled = false
                    },
                    {
                        Button,
                        id = "shareBtn",
                        text = "SHARE",
                        layout_width = "0dp",
                        layout_weight = "0.9",
                        backgroundColor = "#0288D1",
                        textColor = "#FFFFFF",
                        padding = "10dp",
                        layout_marginRight = "4dp"
                    },
                    {
                        Button,
                        id = "downloadBtn",
                        text = "DOWNLOAD",
                        layout_width = "0dp",
                        layout_weight = "1",
                        backgroundColor = "#FF9800",
                        textColor = "#FFFFFF",
                        padding = "10dp"
                    }
                }
            },
            {
                LinearLayout,
                orientation = "horizontal",
                layout_width = "fill",
                layout_height = "wrap",
                {
                    Button,
                    id = "settingBtn",
                    text = "SETTING",
                    layout_width = "0dp",
                    layout_weight = "1",
                    backgroundColor = "#607D8B",
                    textColor = "#FFFFFF",
                    padding = "10dp",
                    layout_marginRight = "5dp"
                },
                {
                    Button,
                    id = "exitBtn",
                    text = "EXIT",
                    layout_width = "0dp",
                    layout_weight = "1",
                    backgroundColor = "#D32F2F",
                    textColor = "#FFFFFF",
                    padding = "10dp",
                    layout_marginLeft = "5dp"
                }
            }
        }
    }

    local mainDialog = LuaDialog(context)
    M.mainDialogRef = mainDialog
    mainDialog.setCancelable(false)
    mainDialog.setView(loadlayout(mainLayout, views))

    pcall(function()
        local win = mainDialog.getWindow()
        if win then
            win.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        end
    end)

    S.ui = {
        statusText = views.statusText,
        createScriptBtn = views.createScriptBtn,
        generateBtn = views.generateBtn,
        resultLayout = views.resultLayout,
        durationLabel = views.durationLabel,
        playBtn = views.playBtnID,
        textInput = views.textInput,
        charCounter = views.charCounter
    }

    local function syncOptionLabels()
        views.modeBtn.setText("Mode: " .. tostring(M.cfg.mode))
        views.singleVoiceBtn.setText("Voice: " .. M.getVoiceDisplayName(M.cfg.singleVoice))
        views.singleStyleBtn.setText("Mood / Style: " .. tostring(M.cfg.singleStyle))
        views.bcMoodBtn.setText("Broadcast Mood: " .. tostring(M.cfg.bcMood))
        views.langBtn.setText("Language: " .. tostring(M.cfg.lang))
        views.durationBtn.setText("Duration: " .. tostring(M.cfg.duration))
        for i = 1, 6 do
            local vBtn = views["spkVoiceBtn_" .. i]
            if vBtn then
                vBtn.setText("Speaker " .. i .. " Voice: " .. M.getVoiceDisplayName(M.cfg.speakerVoices[i] or M.DEFAULT_SPK_VOICES[i]))
            end
        end
    end

    local function applyModeVisibility()
        local sc = M.getModeSpeakerCount(M.cfg.mode)
        M.cfg.speakerCount = sc
        local isSingle = (sc == 1)
        views.singleOptionsLayout.setVisibility(isSingle and View.VISIBLE or View.GONE)
        views.bcOptionsLayout.setVisibility(isSingle and View.GONE or View.VISIBLE)
        if not isSingle then
            for i = 1, 6 do
                local row = views["spkRow_" .. i]
                if row then
                    row.setVisibility(i <= sc and View.VISIBLE or View.GONE)
                end
            end
        end
    end

    local function applyCustomMinVisibility()
        local isCustom = (M.cfg.duration == "Custom Minutes")
        views.customMinInput.setVisibility(isCustom and View.VISIBLE or View.GONE)
    end

    -- Bind Custom Minutes Input
    pcall(function() views.customMinInput.setInputType(InputType.TYPE_CLASS_NUMBER) end)
    views.customMinInput.setText(M.cfg.customMinutes)
    views.customMinInput.addTextChangedListener({
        afterTextChanged = function(editable)
            if M.isUiInitializing then return end
            pcall(function()
                M.cfg.customMinutes = M.trim(editable.toString())
                M.saveSettings()
            end)
        end
    })

    -- Restore Saved Text
    if M.cfg.userText ~= nil and M.cfg.userText ~= "" then
        views.textInput.setText(M.cfg.userText)
        views.charCounter.setText(tostring(views.textInput.getText().length()) .. " chars (Unlimited)")
    end

    views.statusText.setText("[" .. tostring(S.percent) .. "%] " .. S.statusText)
    M.refreshActionButtons()
    if not S.isGenerating and S.generatedAudioPath and File(S.generatedAudioPath).exists() then
        views.resultLayout.setVisibility(View.VISIBLE)
        views.durationLabel.setText("Audio Length: " .. S.currentDurationStr)
        views.playBtnID.setEnabled(true)
        views.playBtnID.setText((S.isPlaying and "PAUSE (" or "PLAY (") .. S.currentDurationStr .. ")")
    end

    -- EditBox Listener: Clearing text manually also stops any active job immediately
    views.textInput.addTextChangedListener({
        afterTextChanged = function(editable)
            if M.isUiInitializing then return end
            pcall(function()
                local newTxt = editable.toString()
                if newTxt ~= M.cfg.userText then
                    M.cfg.userText = newTxt
                    M.saveDraftText(newTxt)
                end
                views.charCounter.setText(tostring(editable.length()) .. " chars (Unlimited)")
                if M.trim(newTxt) == "" and (S.isGenerating or S.isWritingScript) then
                    M.cancelAndResetSession("Text cleared. Generation stopped.")
                else
                    M.refreshActionButtons()
                end
            end)
        end
    })

    -- Bind Direct Picker Buttons (No Spinners = No Scroll-Exit Bug)
    views.modeBtn.onClick = M.safe("pickMode", function()
        M.showListPickerDialog("Select Mode", M.MODE_LIST, nil, M.cfg.mode, function(chosen)
            M.cfg.mode = chosen
            M.saveSettings()
            syncOptionLabels()
            applyModeVisibility()
            M.speakOnly("Mode: " .. chosen)
        end)
    end)

    views.singleVoiceBtn.onClick = M.safe("pickSingleVoice", function()
        M.showVoicePickerDialog("Select Voice (Tap to Preview)", M.cfg.singleVoice, function(chosen)
            M.cfg.singleVoice = chosen
            M.saveSettings()
            syncOptionLabels()
            M.speakOnly("Voice selected: " .. M.getVoiceDisplayName(chosen))
        end)
    end)

    views.singleStyleBtn.onClick = M.safe("pickSingleStyle", function()
        M.showListPickerDialog("Select Mood / Style", M.SINGLE_STYLE_LIST, nil, M.cfg.singleStyle, function(chosen)
            M.cfg.singleStyle = chosen
            M.saveSettings()
            syncOptionLabels()
            M.speakOnly("Style: " .. chosen)
        end)
    end)

    views.bcMoodBtn.onClick = M.safe("pickBcMood", function()
        M.showListPickerDialog("Select Broadcast Mood", M.BROADCAST_MOODS, nil, M.cfg.bcMood, function(chosen)
            M.cfg.bcMood = chosen
            M.saveSettings()
            syncOptionLabels()
            M.speakOnly("Mood: " .. chosen)
        end)
    end)

    views.langBtn.onClick = M.safe("pickLang", function()
        M.showListPickerDialog("Select Language (90 Languages)", M.LANGUAGES, nil, M.cfg.lang, function(chosen)
            M.cfg.lang = chosen
            M.saveSettings()
            syncOptionLabels()
            M.speakOnly("Language: " .. chosen)
        end)
    end)

    views.durationBtn.onClick = M.safe("pickDuration", function()
        M.showListPickerDialog("Select Script Duration", M.DURATION_LIST, nil, M.cfg.duration, function(chosen)
            M.cfg.duration = chosen
            M.saveSettings()
            syncOptionLabels()
            applyCustomMinVisibility()
            M.speakOnly("Duration: " .. chosen)
        end)
    end)

    -- Bind All 6 Speaker Name Inputs & Voice Picker Buttons
    for i = 1, 6 do
        local nameEd = views["spkName_" .. i]
        local voiceBtn = views["spkVoiceBtn_" .. i]
        nameEd.setText(M.cfg.speakerNames[i] or "")
        nameEd.addTextChangedListener({
            afterTextChanged = function(editable)
                if M.isUiInitializing then return end
                pcall(function()
                    M.cfg.speakerNames[i] = M.trim(editable.toString())
                    M.saveSettings()
                end)
            end
        })
        voiceBtn.onClick = M.safe("pickSpkVoice_" .. i, function()
            local curV = M.cfg.speakerVoices[i] or M.DEFAULT_SPK_VOICES[i]
            M.showVoicePickerDialog("Speaker " .. i .. " Voice (Tap to Preview)", curV, function(chosen)
                M.cfg.speakerVoices[i] = chosen
                M.saveSettings()
                syncOptionLabels()
                M.speakOnly("Speaker " .. i .. " voice: " .. M.getVoiceDisplayName(chosen))
            end)
        end)
    end

    syncOptionLabels()
    applyModeVisibility()
    applyCustomMinVisibility()

    -- CLEAR TEXT: Immediately stops active generation, removes audio & resets status to 0%
    views.clearTextBtn.onClick = M.safe("clear", function()
        M.stopPreviewPlayer()
        M.cfg.userText = ""
        M.saveDraftText("")
        M.isUiInitializing = true
        views.textInput.setText("")
        views.charCounter.setText("0 chars (Unlimited)")
        M.isUiInitializing = false
        M.cancelAndResetSession("Text cleared and status reset to ready.")
    end)

    views.playBtnID.onClick = M.safe("play", function()
        M.togglePlayPause(views.playBtnID)
    end)

    views.shareBtn.onClick = M.safe("share", function()
        M.shareAudio()
    end)

    views.downloadBtn.onClick = M.safe("download", function()
        M.showDownloadDialog()
    end)

    -- BUTTON 1: CREATE SCRIPT ONLY (Focus moves to Status)
    views.createScriptBtn.onClick = M.safe("createScript", function()
        M.stopPreviewPlayer()
        if S.isWritingScript or S.isGenerating then
            M.focusStatus()
            M.speakOnly("A task is already running, " .. tostring(S.percent) .. " percent done.")
            return
        end

        local currentText = M.trim(views.textInput.getText().toString())
        if currentText == "" then
            M.speakOnly("Please enter a topic first.")
            return
        end

        if not M.hasAnyApiKey() then
            M.speakOnly("No API key set. Please add at least 1 API key in Settings.")
            return
        end

        M.cfg.userText = currentText
        M.saveDraftText(currentText)
        M.startCreateScriptJob(currentText)
    end)

    -- BUTTON 2: GENERATE AUDIO (Focus moves to Status)
    views.generateBtn.onClick = M.safe("generateAudio", function()
        M.stopPreviewPlayer()
        if S.isGenerating or S.isWritingScript then
            M.focusStatus()
            M.speakOnly("A task is already running, " .. tostring(S.percent) .. " percent done.")
            return
        end

        local currentText = M.trim(views.textInput.getText().toString())
        if currentText == "" then
            M.speakOnly("Please enter text or create a script first.")
            return
        end

        if not M.hasAnyApiKey() then
            M.speakOnly("No API key set. Please add at least 1 API key in Settings.")
            return
        end

        M.cfg.userText = currentText
        M.saveDraftText(currentText)

        if S.mediaPlayer ~= nil then
            pcall(function()
                if S.isPlaying then S.mediaPlayer.stop() end
                S.mediaPlayer.release()
            end)
            S.mediaPlayer = nil
            S.isPlaying = false
        end

        M.deleteOldAudioFile()
        views.playBtnID.setEnabled(false)
        views.playBtnID.setText("PLAY")
        views.resultLayout.setVisibility(View.GONE)

        if M.getModeSpeakerCount(M.cfg.mode) == 1 then
            M.startSingleSpeakerAudioJob(currentText)
        else
            M.startBroadcastAudioJob(currentText)
        end
    end)

    views.settingBtn.onClick = M.safe("setting", function()
        M.stopPreviewPlayer()
        M.showSettingsDialog()
    end)

    -- SMART EXIT: Keeps running in background if busy; auto-cleans audio/session if already finished
    views.exitBtn.onClick = function()
        M.stopPreviewPlayer()
        pcall(function() M.saveDraftText(views.textInput.getText().toString()) end)
        S.ui = nil
        M.mainDialogRef = nil

        if S.isGenerating or S.isWritingScript then
            M.speakOnly("Continuing in background. Re-open anytime to check progress.")
        end
        mainDialog.dismiss()
    end

    mainDialog.show()
    M.delay(300, function()
        M.isUiInitializing = false
        M.refreshActionButtons()
        if M.hasAnyApiKey() and not M.cachedScriptModels then
            pcall(function()
                M.discoverAllWorkingModels(M.getPrimaryApiKey(), function() end)
            end)
        end
    end)
end

-- ============================================================
-- Entry Point
-- ============================================================
local okMain, errMain = pcall(M.showMain)
if not okMain then
    pcall(function() M.logIssue("Startup", tostring(errMain)) end)
    pcall(function() Toast.makeText(context, "Script start error: " .. tostring(errMain), Toast.LENGTH_LONG).show() end)
    pcall(function() service.speak("Script start error: " .. tostring(errMain)) end)
end
