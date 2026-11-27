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
import "android.media.MediaExtractor"
import "android.media.MediaCodec"
import "android.media.MediaCodecList"
import "android.media.MediaFormat"
import "java.nio.ByteBuffer"
import "java.nio.ByteOrder"
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
        cleanVoiceWavPath = nil,
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
M.TARGET_CHARS_PER_PART = 6500
M.PAUSE_DURATION_MS = 380

-- Single Clean Mode Selector (1 to 4 Speakers)
M.MODE_LIST = {
    "Single Speaker (TTS & Story)",
    "2 Speakers Broadcast",
    "3 Speakers Broadcast",
    "4 Speakers Broadcast"
}

function M.getModeSpeakerCount(modeStr)
    local m = tostring(modeStr or "")
    local n = tonumber(m:match("^(%d+)%s+Speakers"))
    if n and n >= 2 and n <= 4 then return n end
    return 1
end

M.MODEL_LIST = {
    "gemini-3.8-flash-tts",
    "gemini-3.8-flash-lite-tts"
}
M.DEFAULT_MODEL = "gemini-3.8-flash-tts"

-- 30 Voices (100% Verified Male/Female Labels in Strict Alternating Male/Female Order)
M.VOICE_LIST = {
    "Puck (Male)", "Kore (Female)",
    "Charon (Male)", "Zephyr (Female)",
    "Fenrir (Male)", "Leda (Female)",
    "Orus (Male)", "Aoede (Female)",
    "Enceladus (Male)", "Callirrhoe (Female)",
    "Iapetus (Male)", "Autonoe (Female)",
    "Umbriel (Male)", "Despina (Female)",
    "Algieba (Male)", "Erinome (Female)",
    "Algenib (Male)", "Laomedeia (Female)",
    "Rasalgethi (Male)", "Achernar (Female)",
    "Alnilam (Male)", "Gacrux (Female)",
    "Schedar (Male)", "Pulcherrima (Female)",
    "Achird (Friendly Male)", "Vindemiatrix (Gentle Female)",
    "Zubenelgenubi (Casual Male)", "Sulafat (Warm Female)",
    "Sadachbia (Lively Male)", "Sadaltager (Knowledgeable Male)"
}

M.RAW_VOICES = {
    "Puck", "Kore",
    "Charon", "Zephyr",
    "Fenrir", "Leda",
    "Orus", "Aoede",
    "Enceladus", "Callirrhoe",
    "Iapetus", "Autonoe",
    "Umbriel", "Despina",
    "Algieba", "Erinome",
    "Algenib", "Laomedeia",
    "Rasalgethi", "Achernar",
    "Alnilam", "Gacrux",
    "Schedar", "Pulcherrima",
    "Achird", "Vindemiatrix",
    "Zubenelgenubi", "Sulafat",
    "Sadachbia", "Sadaltager"
}

M.DEFAULT_SPK_VOICES = { "Puck", "Kore", "Charon", "Zephyr" }

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

-- 38 Unified Moods & Styles (ALL Single + Broadcast Moods in Both Modes, 99-100% Exact Acting Lock)
M.ALL_MOODS_LIST = {
    "Default / Normal",
    "Morning Show / Friendly Chat",
    "Podcast Host (Conversational)",
    "Storytelling (Rich & Expressive)",
    "Story & Discussion",
    "Funny Jokes / Comedy (Punchy)",
    "Comedy Banter (Friends Jokes)",
    "Comedy / Lighthearted",
    "Islamic: Tilawat (Quranic Slow & Melodic)",
    "Islamic: Hadees (Calm Scholar & Tarjuma)",
    "Islamic: Dua (Humble, Soft & Emotional)",
    "Islamic: Naat / Kalam (Sweet & Rhythmic)",
    "Islamic: Waqia / Bayan (Deep & Reverent)",
    "Islamic / Spiritual Reflection",
    "Motivational Speech / Khutba",
    "Motivational / Inspiring",
    "Kids Storyteller (Warm & Playful)",
    "Kids / Cartoon Fun",
    "Cartoon: Thin & Squeaky (Patli Aawaz)",
    "Cartoon: Thick & Goofy (Moti Aawaz)",
    "Bedtime / Calm Sleep (Soothing)",
    "Poetry / Shayari (Deep & Rhythmic)",
    "Dramatic Monologue (Theatrical)",
    "Horror / Scary / Suspense",
    "Thriller / Mystery (Tense)",
    "Sad / Emotional (Heartfelt)",
    "Romantic / Soft (Gentle)",
    "Happy / Joyful (Energetic)",
    "Angry / Aggressive (Forceful)",
    "Whispering / Secretive (ASMR Soft)",
    "Sarcastic / Roast / Irony (Dry Wit)",
    "News Anchor / Breaking News (Formal & Crisp)",
    "Documentary / Deep Dive (Informative)",
    "Educational Q&A / Informative",
    "Debate / Heated Discussion",
    "Interview / Talk Show",
    "Late Night Talk (Warm & Chill)",
    "Dynamic Human (Natural Emotion)"
}

M.SINGLE_STYLE_LIST = M.ALL_MOODS_LIST
M.BROADCAST_MOODS = M.ALL_MOODS_LIST

M.SINGLE_STYLE_TEXT = {
    ["Default / Normal"] = "crystal-clear studio voice, natural balanced narration, crisp articulation, strictly steady medium pace, warm neutral tone",
    ["Morning Show / Friendly Chat"] = "bright, energetic, welcoming morning radio show host tone with crisp cheerful clarity, warm smiles, and lively upbeat rhythm",
    ["Podcast Host (Conversational)"] = "crystal-clear authentic podcast host speaking naturally with relaxed warmth, crisp diction, and smooth conversational rhythm",
    ["Storytelling (Rich & Expressive)"] = "master audiobook storyteller with vivid warmth, crystal-clear enunciation, expressive narrative pacing, and rich immersion",
    ["Story & Discussion"] = "engaging storyteller and thoughtful co-host alternating between vivid narrative flow and warm reactive discussion with crisp clarity",
    ["Funny Jokes / Comedy (Punchy)"] = "witty, upbeat stand-up comedian with crisp comedic timing, playful inflection, lively energy, and natural light chuckle on punchlines",
    ["Comedy Banter (Friends Jokes)"] = "playful, witty friends bantering and cracking jokes with crisp timing, teasing warmth, and upbeat joyful energy",
    ["Comedy / Lighthearted"] = "cheerful, playful, lighthearted delivery with a smiling tone, crisp voice clarity, and lively steady rhythm",
    ["Islamic: Tilawat (Quranic Slow & Melodic)"] = "reverent, slow, deeply spiritual and melodic Quranic Qirat style with measured breath pauses, elongated vowels, calm serenity, and strictly uniform slow tempo",
    ["Islamic: Hadees (Calm Scholar & Tarjuma)"] = "dignified, respectful Islamic scholar reciting clearly with solemn reverence, crystal-clear pronunciation, gentle pauses, and calm steady pace",
    ["Islamic: Dua (Humble, Soft & Emotional)"] = "deeply humble, trembling, soft pleading prayerful voice filled with sincerity, slow unhurried pace, and heartfelt emotion",
    ["Islamic: Naat / Kalam (Sweet & Rhythmic)"] = "sweet, soulful, melodic and rhythmic Naat recitation with respectful softness, crystal-clear diction, and steady poetic cadence",
    ["Islamic: Waqia / Bayan (Deep & Reverent)"] = "deep, solemn, captivating Islamic scholar and historical narrator with gravitas, crystal-clear articulation, and steady reverent flow",
    ["Islamic / Spiritual Reflection"] = "serene, thoughtful, spiritually uplifting tone with calm wisdom, crisp clarity, and peaceful measured pacing",
    ["Motivational Speech / Khutba"] = "powerful, commanding, inspiring orator delivering a heartfelt speech with resonant studio clarity, purposeful pauses, and confident energy",
    ["Motivational / Inspiring"] = "uplifting, confident, encouraging mentor voice with crisp strong clarity and inspiring forward momentum",
    ["Kids Storyteller (Warm & Playful)"] = "cheerful, gentle, animated children's storyteller with bright crystal clarity, playful warmth, and easy-to-follow pace",
    ["Kids / Cartoon Fun"] = "lively, bright, playful cartoon-style fun voice with cheerful enthusiasm, animated reactions, and crisp clear speech",
    ["Cartoon: Thin & Squeaky (Patli Aawaz)"] = "high-pitched, thin, squeaky, quirky animated cartoon character voice kept 100% consistent and clear throughout",
    ["Cartoon: Thick & Goofy (Moti Aawaz)"] = "deep, booming, thick goofy cartoon character voice with slow playful charm kept 100% consistent and clear throughout",
    ["Bedtime / Calm Sleep (Soothing)"] = "ultra-calm, hushed, soothing bedtime voice with very slow tempo, soft gentle warmth, and peaceful relaxation",
    ["Poetry / Shayari (Deep & Rhythmic)"] = "deep, soulful classical poet voice with deliberate rhythmic pauses, crystal-clear emotional resonance, and lyrical flow",
    ["Dramatic Monologue (Theatrical)"] = "intense, theatrical stage actor delivering a gripping monologue with rich vocal weight, crisp projection, and controlled dramatic pauses",
    ["Horror / Scary / Suspense"] = "eerie, low, chilling suspense voice with slow creeping tension, hushed dread, crisp whispered emphasis, and unsettling pauses",
    ["Thriller / Mystery (Tense)"] = "focused, taut, high-stakes thriller delivery with sharp crisp urgency and controlled suspenseful pacing",
    ["Sad / Emotional (Heartfelt)"] = "sorrowful, tender, heavy-hearted voice with genuine quiet grief, slow pace, and soft heartfelt fragility",
    ["Romantic / Soft (Gentle)"] = "intimate, velvety, warm romantic voice with gentle tenderness, soft clarity, and slow affectionate delivery",
    ["Happy / Joyful (Energetic)"] = "bright, joyful, enthusiastic voice radiating genuine happiness, crisp clarity, and upbeat energy",
    ["Angry / Aggressive (Forceful)"] = "intense, stern, forceful angry voice with sharp crisp emphasis and controlled fiery authority",
    ["Whispering / Secretive (ASMR Soft)"] = "close, quiet, secretive whisper with delicate crisp softness and steady hushed volume",
    ["Sarcastic / Roast / Irony (Dry Wit)"] = "deadpan, sharp, playfully sarcastic roast delivery with dry wit, crisp punchy timing, and composed comedic skepticism",
    ["News Anchor / Breaking News (Formal & Crisp)"] = "authoritative, crisp, studio-grade broadcast news anchor with urgent clarity, strictly uniform medium pace, and professional precision",
    ["Documentary / Deep Dive (Informative)"] = "calm, knowledgeable, prestigious documentary voice with crystal-clear articulation and measured informative cadence",
    ["Educational Q&A / Informative"] = "clear, patient, knowledgeable teacher and curious learner exchange with crisp pronunciation and well-paced explanations",
    ["Debate / Heated Discussion"] = "passionate, articulate, sharp debate speakers presenting strong counter-arguments with crisp emphasis and lively energy",
    ["Interview / Talk Show"] = "polished, engaging talk show host and guest speaking with crisp broadcast clarity, natural curiosity, and smooth turn-taking",
    ["Late Night Talk (Warm & Chill)"] = "smooth, relaxed, cozy late-night radio voice with mellow warmth, crisp intimate clarity, and unhurried conversational flow",
    ["Dynamic Human (Natural Emotion)"] = "highly lifelike, naturally expressive crystal-clear human voice adapting smoothly to the text's emotion while keeping the exact same voice"
}

function M.getMoodActingInstruction(moodName)
    local base = M.SINGLE_STYLE_TEXT[moodName]
    if base then return base end
    return "crystal-clear studio voice strictly performing in " .. tostring(moodName or "Default / Normal") .. " style with crisp natural pronunciation and zero muffling"
end

-- Complete English (USA) User Guide
M.USER_GUIDE_TEXT = table.concat({
    "GEMINI AUDIO & BROADCAST STUDIO - USER GUIDE (v14)",
    "",
    "1. 5 API KEYS & AUTO-MODEL FAILOVER:",
    "- Open SETTING -> SET API KEYS (1-5) to add up to 5 Google Gemini API Keys.",
    "- The studio automatically discovers active Script and Audio (TTS) models on your key.",
    "- If a TTS model hits a limit (429/503), it waits 5 seconds to recheck once, then waits 4 seconds and automatically switches to the next active TTS model from the exact remaining part.",
    "",
    "2. 1 TO 4 SPEAKERS & PERMANENT VOICE SAMPLES:",
    "- Tap Mode to switch between Single Speaker and 2, 3, or 4 Speakers Broadcast.",
    "- Tap any Voice button to open the 30-voice list (100% verified Male/Female labels in alternating order).",
    "- Double-tap any voice to check it, hear TTS confirmation, and play a short sample. Tap the bottom-right DONE button to confirm.",
    "- Voice samples are saved permanently in private app storage (hidden from Phone Storage & Music Players) and shared across all 1-4 speaker modes so no extra API requests are wasted.",
    "",
    "3. 90 LANGUAGES, 38 UNIFIED MOODS & SMART LIMITS:",
    "- Choose from 90 languages (Urdu Pakistan #1, English USA #2, and 88 more) and 38 unified moods/styles available in both Single Speaker and Broadcast modes.",
    "- Single Speaker supports 6,500 to 7,000 characters per part; Broadcast supports 5,500 characters per part with strict tone, pitch, and crystal-clear voice lock.",
    "",
    "4. BACKGROUND MUSIC & AUTO-DUCKING (100% OFFLINE):",
    "- Tap ADD BACKGROUND MUSIC (optional) to pick any MP3, WAV, or M4A track from phone storage.",
    "- Open SETTING -> BG MUSIC & DUCKING SETTINGS to customize Music Volume During Voice (%), Intro/Outro/Pause Volume (%), Intro & Outro Time (0-5 sec), Voice Clarity Boost (%), and Auto-Ducking ON/OFF.",
    "- After audio is ready, you can change or apply background music offline anytime using APPLY / UPDATE BG MUSIC (0 API requests).",
    "",
    "5. LIVE 5%-100% PROGRESS, ZERO-DELETE AUTO-RESUME & MP3 DOWNLOAD:",
    "- CREATE SCRIPT, GENERATE AUDIO, and BG Music Mixing all show live 5% to 100% progress.",
    "- Completed parts are saved safely even if quota runs out, the extension closes, or the phone restarts. Tap RESUME AUDIO or RESUME SCRIPT to continue from the exact next part.",
    "- Tap DOWNLOAD to save directly to Phone Storage (Downloads) as .mp3. Saved parts are ONLY deleted when you tap DOWNLOAD or CLEAR TEXT."
}, "\n")

-- Preferences & Storage Paths
M.prefs = context.getSharedPreferences("Jieshuo_Gemini_ABS_V4", Context.MODE_PRIVATE)
M.baseStorageDir = context.getFilesDir() or context.getCacheDir()
M.previewCacheDir = File(M.baseStorageDir, "abs_v4_voice_previews_perm")
if not M.previewCacheDir.exists() then M.previewCacheDir.mkdirs() end
M.resumeDir = File(M.baseStorageDir, "abs_v4_resume_parts")
if not M.resumeDir.exists() then M.resumeDir.mkdirs() end

-- Active User Config (5 API Keys)
M.cfg = {
    mode = "Single Speaker (TTS & Story)",
    speakerCount = 1,
    singleVoice = "Puck",
    singleStyle = "Default / Normal",
    speakerVoices = { "Puck", "Kore", "Charon", "Zephyr" },
    speakerNames = { "", "", "", "" },
    bgMusicPath = "",
    bgMusicName = "",
    bgDuckVol = 12,
    bgNormalVol = 38,
    bgIntroOutroSec = 3,
    bgVoiceBoost = 100,
    bgAutoDuck = true,
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
        local srcStr = tostring(source or "")
        local entry
        if srcStr:find("Script", 1, true) or srcStr:find("ListModels", 1, true) then
            entry = string.format("[%s] Mode: %s | %s: %s",
                ts, tostring(M.cfg.mode), srcStr, tostring(message))
        else
            entry = string.format("[%s] Mode: %s | AudioModel: %s | %s: %s",
                ts, tostring(M.cfg.mode), tostring(M.cfg.model), srcStr, tostring(message))
        end
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



M.progressTickerId = 0

function M.stopProgressTicker()
    M.progressTickerId = (M.progressTickerId or 0) + 1
end

function M.startProgressTicker(myJobId, startPct, maxPct, stepMs, labelText)
    M.stopProgressTicker()
    local tid = M.progressTickerId
    local cur = math.max(5, math.min(95, math.floor(startPct or 5)))
    local cap = math.max(cur, math.min(95, math.floor(maxPct or 90)))
    local interval = stepMs or 1600

    local function tick()
        if M.progressTickerId ~= tid then return end
        if S.jobId ~= myJobId then return end
        if not S.isWritingScript and not S.isGenerating then return end
        if cur < cap then
            cur = math.min(cap, cur + 5)
            M.updateProgress(cur, labelText, false)
            M.delay(interval, tick)
        end
    end
    M.delay(interval, tick)
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
        ed.remove("last_clean_wav_path")
        ed.commit()
    end)
end

function M.cancelAndResetSession(speakNotice)
    S.jobId = (S.jobId or 0) + 1
    M.stopProgressTicker()
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
    for i = 1, 4 do
        ed.putString("spk_voice_" .. i, M.cfg.speakerVoices[i] or M.DEFAULT_SPK_VOICES[i])
        ed.putString("spk_name_" .. i, M.cfg.speakerNames[i] or "")
    end
    ed.putString("bg_music_path", M.cfg.bgMusicPath or "")
    ed.putString("bg_music_name", M.cfg.bgMusicName or "")
    ed.putInt("bg_duck_vol", tonumber(M.cfg.bgDuckVol) or 12)
    ed.putInt("bg_normal_vol", tonumber(M.cfg.bgNormalVol) or 38)
    ed.putInt("bg_intro_outro_sec", tonumber(M.cfg.bgIntroOutroSec) or 3)
    ed.putInt("bg_voice_boost", tonumber(M.cfg.bgVoiceBoost) or 100)
    ed.putBoolean("bg_auto_duck", M.cfg.bgAutoDuck ~= false)
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
    for i = 1, 4 do
        M.cfg.speakerVoices[i] = M.prefs.getString("spk_voice_" .. i, M.DEFAULT_SPK_VOICES[i])
        M.cfg.speakerNames[i] = M.prefs.getString("spk_name_" .. i, "")
    end
    M.cfg.bgMusicPath = M.prefs.getString("bg_music_path", "")
    M.cfg.bgMusicName = M.prefs.getString("bg_music_name", "")
    M.cfg.bgDuckVol = M.prefs.getInt("bg_duck_vol", 12)
    M.cfg.bgNormalVol = M.prefs.getInt("bg_normal_vol", 38)
    M.cfg.bgIntroOutroSec = M.prefs.getInt("bg_intro_outro_sec", 3)
    M.cfg.bgVoiceBoost = M.prefs.getInt("bg_voice_boost", 100)
    M.cfg.bgAutoDuck = M.prefs.getBoolean("bg_auto_duck", true)
    if M.cfg.bgMusicPath ~= "" then
        local mf = File(M.cfg.bgMusicPath)
        if not mf.exists() then
            M.cfg.bgMusicPath = ""
            M.cfg.bgMusicName = ""
        end
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
    if not S.cleanVoiceWavPath then
        local savedClean = M.prefs.getString("last_clean_wav_path", "")
        if savedClean ~= "" then
            local cf = File(savedClean)
            if cf.exists() and cf.length() > 100 then
                S.cleanVoiceWavPath = savedClean
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
                elseif not lower:find("omni", 1, true)
                    and not lower:find("exp", 1, true)
                    and not lower:find("thinking", 1, true)
                    and not lower:find("live", 1, true)
                    and not lower:find("image", 1, true)
                    and not lower:find("audio", 1, true)
                    and not lower:find("embedding", 1, true)
                    and not lower:find("veo", 1, true)
                    and not lower:find("robotics", 1, true)
                    and not lower:find("computer", 1, true)
                    and not lower:find("vision", 1, true) then
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

        -- Highest-quota & fastest Free-Tier Flash-Lite models first, then stable Flash, then others
        local scriptList = {}
        for _, v in ipairs(fastFlashText) do table.insert(scriptList, v) end
        for _, v in ipairs(otherFlashText) do table.insert(scriptList, v) end
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
    if S.cleanVoiceWavPath then
        pcall(function()
            local cf = File(S.cleanVoiceWavPath)
            if cf.exists() then cf.delete() end
        end)
        S.cleanVoiceWavPath = nil
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

-- Shared Permanent Voice Sample Preview (Cached Once Across ALL Modes: 1-4 Speakers)
function M.previewVoiceSample(voiceName)
    if not voiceName or voiceName == "" then return end
    if S.isGenerating or S.isWritingScript then return end

    if not M.previewCacheDir.exists() then M.previewCacheDir.mkdirs() end
    local cacheFile = File(M.previewCacheDir, "preview_" .. tostring(voiceName) .. ".wav")
    if cacheFile.exists() and cacheFile.length() > 1000 then
        M.playPreviewFile(cacheFile.getAbsolutePath())
        return
    end

    if not M.hasAnyApiKey() then
        M.speakOnly("Add an API key in Settings to hear voice sample.")
        return
    end

    local headers = HashMap()
    headers.put("Content-Type", "application/json")
    local sampleText = "Hello, I am " .. tostring(voiceName) .. ". This is my voice test sample."
    local primaryKey = M.getNextApiKey()

    M.discoverWorkingTtsModels(primaryKey, M.cfg.model, function(ttsQueue)
        if not ttsQueue or #ttsQueue == 0 then ttsQueue = { M.cfg.model } end

        local function tryPreview(ttsIdx, curKey, keyRetries)
            local curModel = ttsQueue[ttsIdx]
            if not curModel then
                M.speakOnly("Voice sample busy right now. Try again later.")
                return
            end
            local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. tostring(curModel) .. ":generateContent?key=" .. tostring(curKey)
            local payload = {
                contents = { { role = "user", parts = { { text = sampleText } } } },
                generationConfig = {
                    responseModalities = { "AUDIO" },
                    speechConfig = { voiceConfig = { voice = voiceName } }
                }
            }
            M.httpPost(url, cjson.encode(payload), headers, function(code, content)
                if code == 429 or code == 503 or code == 500 or code == -1 or code == 404 then
                    local altKey = M.getAlternateApiKey(curKey)
                    if altKey and keyRetries < 4 then
                        M.delay(250, function() tryPreview(ttsIdx, altKey, keyRetries + 1) end)
                        return
                    elseif ttsIdx < #ttsQueue then
                        M.delay(300, function() tryPreview(ttsIdx + 1, M.getNextApiKey(), 0) end)
                        return
                    end
                    M.speakOnly("Voice sample limit reached.")
                    return
                end
                if code ~= 200 then
                    M.speakOnly("Voice sample error " .. tostring(code))
                    return
                end

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

        tryPreview(1, primaryKey, 0)
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


-- ============================================================
-- 100% CRASH-FREE OFFLINE BACKGROUND MUSIC MIXER
-- (Safe Chunked mainHandler Engine - No Unsafe Lua Threads!)
-- 3s Intro -> Smooth Auto-Ducking (Crystal-Clear Voice) -> 3s Outro Fade-Out
-- Live 5% to 100% Progress Reporting
-- ============================================================
function M.decodeAudioFileAsync(musicPath, targetSamples, isCanceledFn, onProgress, onDone)
    local f = File(musicPath)
    if not f.exists() or f.length() < 100 then
        onDone(false, "Music file missing")
        return
    end

    if musicPath:lower():match("%.wav$") then
        local okOpen, state = pcall(function()
            local fis = FileInputStream(f)
            local hdr = byte[44]
            local hr = fis.read(hdr, 0, 44)
            if hr == 44 and hdr[0] == 82 and hdr[1] == 73 and hdr[2] == 70 and hdr[3] == 70 then
                local ch = (hdr[22] % 256) + ((hdr[23] % 256) * 256)
                local sr = (hdr[24] % 256) + ((hdr[25] % 256) * 256) + ((hdr[26] % 256) * 65536) + ((hdr[27] % 256) * 16777216)
                if ch < 1 then ch = 1 end
                if sr < 8000 then sr = 24000 end
                local maxRaw = math.min(math.floor(sr * 120), math.floor(targetSamples * (sr / 24000.0)) + sr)
                return { fis = fis, ch = ch, sr = sr, maxRaw = maxRaw, rawMono = {}, buf = byte[16384] }
            end
            fis.close()
            return nil
        end)
        if okOpen and state then
            local function stepWav()
                if isCanceledFn and isCanceledFn() then
                    pcall(function() state.fis.close() end)
                    onDone(false, "Canceled")
                    return
                end
                local doneFlag = false
                local okStep, errStep = pcall(function()
                    for _ = 1, 3 do
                        if #state.rawMono >= state.maxRaw then doneFlag = true break end
                        local n = state.fis.read(state.buf, 0, 16384)
                        if not n or n <= 0 then doneFlag = true break end
                        local step = state.ch * 2
                        local i = 0
                        while i + step - 1 < n do
                            local sum = 0
                            for c = 0, state.ch - 1 do
                                local lo = state.buf[i + c * 2] % 256
                                local hi = state.buf[i + c * 2 + 1] % 256
                                local v = lo + hi * 256
                                if v >= 32768 then v = v - 65536 end
                                sum = sum + v
                            end
                            table.insert(state.rawMono, math.floor(sum / state.ch))
                            i = i + step
                        end
                    end
                end)
                if not okStep then
                    pcall(function() state.fis.close() end)
                    onDone(false, tostring(errStep))
                    return
                end
                local pct = 5 + math.floor(math.min(1, #state.rawMono / math.max(1, state.maxRaw)) * 25)
                if onProgress then onProgress(pct) end
                if doneFlag then
                    pcall(function() state.fis.close() end)
                    if #state.rawMono == 0 then
                        onDone(false, "Empty WAV music")
                        return
                    end
                    local ratio = state.sr / 24000.0
                    local outLen = math.floor(#state.rawMono / ratio)
                    local outSamples = {}
                    for k = 1, outLen do
                        local sp = math.floor((k - 1) * ratio) + 1
                        if sp > #state.rawMono then sp = #state.rawMono end
                        outSamples[k] = state.rawMono[sp]
                    end
                    onDone(true, outSamples)
                else
                    M.delay(8, stepWav)
                end
            end
            M.delay(8, stepWav)
            return
        end
    end

    local okInit, dec = pcall(function()
        local extractor = MediaExtractor()
        extractor.setDataSource(musicPath)
        local trackIdx, mime, srcFormat = -1, nil, nil
        local numTracks = extractor.getTrackCount()
        for t = 0, numTracks - 1 do
            local fmt = extractor.getTrackFormat(t)
            local m = fmt.getString(MediaFormat.KEY_MIME)
            if m and m:sub(1, 6) == "audio/" then
                trackIdx = t
                mime = m
                srcFormat = fmt
                break
            end
        end
        if trackIdx < 0 or not mime then
            extractor.release()
            error("No audio track found in selected music file")
        end
        extractor.selectTrack(trackIdx)
        local srcRate = 44100
        local srcCh = 2
        pcall(function() srcRate = srcFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE) end)
        pcall(function() srcCh = srcFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT) end)
        if not srcRate or srcRate < 8000 then srcRate = 44100 end
        if not srcCh or srcCh < 1 then srcCh = 2 end

        local codec = MediaCodec.createDecoderByType(mime)
        codec.configure(srcFormat, nil, nil, 0)
        codec.start()

        local maxNeededSrc = math.min(math.floor(srcRate * 90), math.floor(targetSamples * (srcRate / 24000.0)) + srcRate)
        return {
            extractor = extractor,
            codec = codec,
            info = MediaCodec.BufferInfo(),
            srcRate = srcRate,
            srcCh = srcCh,
            sawInputEOS = false,
            sawOutputEOS = false,
            rawMono = {},
            maxNeededSrc = maxNeededSrc,
            totalLoops = 0
        }
    end)

    if not okInit or not dec then
        onDone(false, tostring(dec or "Cannot open music decoder"))
        return
    end

    local function closeDec()
        pcall(function() dec.codec.stop() end)
        pcall(function() dec.codec.release() end)
        pcall(function() dec.extractor.release() end)
    end

    local function stepCodec()
        if isCanceledFn and isCanceledFn() then
            closeDec()
            onDone(false, "Canceled")
            return
        end

        local okS, errS = pcall(function()
            local batchLoops = 0
            while not dec.sawOutputEOS and #dec.rawMono < dec.maxNeededSrc and dec.totalLoops < 25000 and batchLoops < 35 do
                dec.totalLoops = dec.totalLoops + 1
                batchLoops = batchLoops + 1

                if not dec.sawInputEOS then
                    local inIdx = dec.codec.dequeueInputBuffer(2000)
                    if inIdx >= 0 then
                        local inBuf = dec.codec.getInputBuffer(inIdx)
                        local sampleSize = dec.extractor.readSampleData(inBuf, 0)
                        if sampleSize < 0 then
                            dec.codec.queueInputBuffer(inIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            dec.sawInputEOS = true
                        else
                            local pts = dec.extractor.getSampleTime()
                            dec.codec.queueInputBuffer(inIdx, 0, sampleSize, pts, 0)
                            dec.extractor.advance()
                        end
                    end
                end

                local outIdx = dec.codec.dequeueOutputBuffer(dec.info, 2000)
                if outIdx >= 0 then
                    if dec.info.size > 0 then
                        local outBuf = dec.codec.getOutputBuffer(outIdx)
                        outBuf.position(dec.info.offset)
                        outBuf.limit(dec.info.offset + dec.info.size)
                        local chunk = byte[dec.info.size]
                        outBuf.get(chunk)
                        local step = dec.srcCh * 2
                        local i = 0
                        while i + step - 1 < dec.info.size do
                            local sum = 0
                            for c = 0, dec.srcCh - 1 do
                                local lo = chunk[i + c * 2] % 256
                                local hi = chunk[i + c * 2 + 1] % 256
                                local v = lo + hi * 256
                                if v >= 32768 then v = v - 65536 end
                                sum = sum + v
                            end
                            table.insert(dec.rawMono, math.floor(sum / dec.srcCh))
                            i = i + step
                        end
                    end
                    dec.codec.releaseOutputBuffer(outIdx, false)
                    if (dec.info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) ~= 0 then
                        dec.sawOutputEOS = true
                    end
                elseif outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED then
                    local ofmt = dec.codec.getOutputFormat()
                    pcall(function() dec.srcRate = ofmt.getInteger(MediaFormat.KEY_SAMPLE_RATE) end)
                    pcall(function() dec.srcCh = ofmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT) end)
                end
            end
        end)

        if not okS then
            closeDec()
            onDone(false, tostring(errS))
            return
        end

        local pct = 5 + math.floor(math.min(1, #dec.rawMono / math.max(1, dec.maxNeededSrc)) * 25)
        if onProgress then onProgress(pct) end

        if dec.sawOutputEOS or #dec.rawMono >= dec.maxNeededSrc or dec.totalLoops >= 25000 then
            closeDec()
            if #dec.rawMono == 0 then
                onDone(false, "Decoded music was empty")
                return
            end
            local ratio = dec.srcRate / 24000.0
            local outLen = math.floor(#dec.rawMono / ratio)
            local outSamples = {}
            for k = 1, outLen do
                local sp = math.floor((k - 1) * ratio) + 1
                if sp > #dec.rawMono then sp = #dec.rawMono end
                outSamples[k] = dec.rawMono[sp]
            end
            onDone(true, outSamples)
        else
            M.delay(8, stepCodec)
        end
    end

    M.delay(8, stepCodec)
end

function M.mixVoiceWithBgMusic(cleanWavPath, musicPath, onDone)
    local myJobId = S.jobId
    local function isCanceled()
        return S.jobId ~= myJobId
    end

    local vf = File(cleanWavPath)
    if not vf.exists() or vf.length() <= 44 then
        onDone(false, "Clean voice file missing", 0)
        return
    end

    local voicePcmBytes = math.floor(vf.length()) - 44
    if voicePcmBytes % 2 ~= 0 then voicePcmBytes = voicePcmBytes - 1 end
    local voiceSamples = math.floor(voicePcmBytes / 2)

    local sr = 24000
    local ioSec = math.max(0, math.min(10, tonumber(M.cfg.bgIntroOutroSec) or 3))
    local duckGain = math.max(0.02, math.min(0.80, (tonumber(M.cfg.bgDuckVol) or 12) / 100.0))
    local normGain = math.max(0.05, math.min(0.95, (tonumber(M.cfg.bgNormalVol) or 38) / 100.0))
    local voiceGain = math.max(0.80, math.min(1.50, (tonumber(M.cfg.bgVoiceBoost) or 100) / 100.0))
    local autoDuckOn = (M.cfg.bgAutoDuck ~= false)
    local introSamples = sr * ioSec
    local outroSamples = sr * ioSec
    local totalSamples = introSamples + voiceSamples + outroSamples
    local totalPcmBytes = totalSamples * 2
    local totalDurSec = totalSamples / 24000.0

    M.updateProgress(5, "Decoding background music (5%)...", false)

    M.decodeAudioFileAsync(musicPath, totalSamples, isCanceled, function(decPct)
        M.updateProgress(decPct, "Preparing background music (" .. tostring(decPct) .. "%)...", false)
    end, function(okDec, bgSamplesOrErr)
        if isCanceled() then onDone(false, "Canceled", 0) return end
        if not okDec then
            onDone(false, tostring(bgSamplesOrErr or "Music decode failed"), 0)
            return
        end

        local bgSamples = bgSamplesOrErr
        local bgLen = #bgSamples
        local mixedPath = M.baseStorageDir.getPath() .. "/gemini_mixed_" .. os.time() .. ".wav"

        local okOpen, st = pcall(function()
            local fos = FileOutputStream(File(mixedPath))
            M.writeWavHeader(fos, totalPcmBytes)
            local fis = FileInputStream(vf)
            local skipHdr = byte[44]
            fis.read(skipHdr, 0, 44)
            return {
                fos = fos,
                fis = fis,
                frameSize = 960,
                inBytes = byte[960 * 2],
                outBytes = byte[960 * 2],
                curGain = normGain,
                bgCursor = 1,
                globalPos = 0,
                phase = 1,
                remIntro = introSamples,
                remVoice = voiceSamples,
                remOutro = outroSamples
            }
        end)

        if not okOpen or not st then
            onDone(false, tostring(st or "Cannot open output WAV"), 0)
            return
        end

        local function closeStreams()
            pcall(function() st.fis.close() end)
            pcall(function() st.fos.flush() st.fos.close() end)
        end

        local function writeMixedFrame(vArr, vCount, targetGain, isIntro, isOutro)
            local outIdx = 0
            local outB = st.outBytes
            for i = 0, vCount - 1 do
                st.globalPos = st.globalPos + 1
                local vSample = 0
                if vArr then
                    local lo = vArr[i * 2] % 256
                    local hi = vArr[i * 2 + 1] % 256
                    vSample = lo + hi * 256
                    if vSample >= 32768 then vSample = vSample - 65536 end
                end

                if targetGain < st.curGain then
                    st.curGain = st.curGain + (targetGain - st.curGain) * 0.0030
                else
                    st.curGain = st.curGain + (targetGain - st.curGain) * 0.0008
                end

                local envGain = st.curGain
                if isIntro and st.globalPos < 12000 then
                    envGain = envGain * (st.globalPos / 12000.0)
                end
                if isOutro then
                    local remEnd = totalSamples - st.globalPos
                    if remEnd < 36000 then
                        envGain = envGain * math.max(0.0, remEnd / 36000.0)
                    end
                end

                local mSample = bgSamples[st.bgCursor] or 0
                st.bgCursor = st.bgCursor + 1
                if st.bgCursor > bgLen then st.bgCursor = 1 end

                local mixed = math.floor((vSample * voiceGain) + (mSample * envGain))
                if mixed > 32767 then mixed = 32767
                elseif mixed < -32768 then mixed = -32768 end

                if mixed < 0 then mixed = mixed + 65536 end
                outB[outIdx] = mixed % 256
                outB[outIdx + 1] = math.floor(mixed / 256) % 256
                outIdx = outIdx + 2
            end
            st.fos.write(outB, 0, outIdx)
        end

        local function stepMix()
            if isCanceled() then
                closeStreams()
                pcall(function() File(mixedPath).delete() end)
                onDone(false, "Canceled", 0)
                return
            end

            local okStep, errStep = pcall(function()
                for _ = 1, 25 do
                    if st.phase == 1 then
                        if st.remIntro <= 0 then
                            st.phase = 2
                        else
                            local cnt = math.min(st.frameSize, st.remIntro)
                            local tGain = (st.remIntro <= 9600 and autoDuckOn) and duckGain or normGain
                            writeMixedFrame(nil, cnt, tGain, true, false)
                            st.remIntro = st.remIntro - cnt
                        end
                    elseif st.phase == 2 then
                        if st.remVoice <= 0 then
                            st.phase = 3
                        else
                            local cnt = math.min(st.frameSize, st.remVoice)
                            local bytesRead = st.fis.read(st.inBytes, 0, cnt * 2)
                            if not bytesRead or bytesRead <= 0 then
                                st.remVoice = 0
                                st.phase = 3
                            else
                                local actualSamples = math.floor(bytesRead / 2)
                                local energy = 0
                                for i = 0, actualSamples - 1 do
                                    local lo = st.inBytes[i * 2] % 256
                                    local hi = st.inBytes[i * 2 + 1] % 256
                                    local s = lo + hi * 256
                                    if s >= 32768 then s = s - 65536 end
                                    energy = energy + (s * s)
                                end
                                local rms = math.sqrt(energy / math.max(1, actualSamples))
                                local targetGain = autoDuckOn and ((rms > 380) and duckGain or normGain) or duckGain
                                writeMixedFrame(st.inBytes, actualSamples, targetGain, false, false)
                                st.remVoice = st.remVoice - actualSamples
                            end
                        end
                    elseif st.phase == 3 then
                        if st.remOutro <= 0 then
                            st.phase = 4
                            break
                        else
                            local cnt = math.min(st.frameSize, st.remOutro)
                            writeMixedFrame(nil, cnt, normGain, false, true)
                            st.remOutro = st.remOutro - cnt
                        end
                    else
                        break
                    end
                end
            end)

            if not okStep then
                closeStreams()
                pcall(function() File(mixedPath).delete() end)
                onDone(false, tostring(errStep), 0)
                return
            end

            local mixPct = 35 + math.floor(math.min(1, st.globalPos / math.max(1, totalSamples)) * 60)
            M.updateProgress(mixPct, "Auto-Ducking & Mixing BG Music (" .. tostring(mixPct) .. "%)...", false)

            if st.phase >= 4 then
                closeStreams()
                if File(mixedPath).exists() and File(mixedPath).length() > 100 then
                    onDone(true, mixedPath, totalDurSec)
                else
                    onDone(false, "Mixed output file was empty", 0)
                end
            else
                M.delay(5, stepMix)
            end
        end

        M.delay(5, stepMix)
    end)
end

function M.exportToMp3File(sourceWavPath, destMp3File)
    local usedFfmpeg = false
    pcall(function()
        local ffPaths = { "/system/bin/ffmpeg", "/data/data/com.termux/files/usr/bin/ffmpeg", "ffmpeg" }
        for _, ff in ipairs(ffPaths) do
            local okExec, proc = pcall(function()
                return luajava.bindClass("java.lang.Runtime").getRuntime().exec({
                    ff, "-y", "-i", sourceWavPath, "-codec:a", "libmp3lame", "-b:a", "128k", destMp3File.getAbsolutePath()
                })
            end)
            if okExec and proc then
                local exitCode = proc.waitFor()
                if exitCode == 0 and destMp3File.exists() and destMp3File.length() > 1000 then
                    usedFfmpeg = true
                    break
                end
            end
        end
    end)
    if usedFfmpeg then return true end

    local okCopy, errCopy = pcall(function()
        local input = FileInputStream(File(sourceWavPath))
        local output = FileOutputStream(destMp3File)
        copyStream(input, output)
        output.flush()
        output.close()
        input.close()
    end)
    return okCopy, errCopy
end

function M.applyBgMusicNow()
    if S.isGenerating or S.isWritingScript then
        M.speakOnly("Please wait for the current task to finish.")
        return
    end
    local cleanPath = S.cleanVoiceWavPath or S.generatedAudioPath
    if not cleanPath or not File(cleanPath).exists() then
        M.speakOnly("Please generate audio first.")
        return
    end

    if S.mediaPlayer ~= nil then
        pcall(function()
            if S.isPlaying then S.mediaPlayer.stop() end
            S.mediaPlayer.release()
        end)
        S.mediaPlayer = nil
        S.isPlaying = false
    end

    if not M.cfg.bgMusicPath or M.cfg.bgMusicPath == "" or not File(M.cfg.bgMusicPath).exists() then
        if S.generatedAudioPath and S.generatedAudioPath ~= cleanPath then
            pcall(function() File(S.generatedAudioPath).delete() end)
        end
        S.generatedAudioPath = cleanPath
        local durSec = math.max(1, (File(cleanPath).length() - 44) / 48000.0)
        M.onAudioReadyUI(durSec, "Audio (No BG Music)")
        return
    end

    S.jobId = (S.jobId or 0) + 1
    S.isGenerating = true
    M.refreshActionButtons()
    M.focusStatus()
    M.updateProgress(5, "Starting Auto-Ducking & BG Music Mix...", true)
    M.mixVoiceWithBgMusic(cleanPath, M.cfg.bgMusicPath, function(okMix, pathOrErr, durSec)
        if okMix then
            if S.generatedAudioPath and S.generatedAudioPath ~= cleanPath then
                pcall(function() File(S.generatedAudioPath).delete() end)
            end
            S.generatedAudioPath = pathOrErr
            M.onAudioReadyUI(durSec, "Audio + BG Music")
        else
            S.isGenerating = false
            M.logIssue("BgMusicMix", tostring(pathOrErr))
            M.updateProgress(100, "Music mix failed (" .. tostring(pathOrErr) .. "). Original voice kept.", true)
            M.refreshActionButtons()
        end
    end)
end

function M.finalizeMergedVoice(durSec, labelPrefix)
    S.cleanVoiceWavPath = S.generatedAudioPath
    pcall(function()
        local ed = M.prefs.edit()
        ed.putString("last_clean_wav_path", tostring(S.cleanVoiceWavPath or ""))
        ed.commit()
    end)

    if M.cfg.bgMusicPath and M.cfg.bgMusicPath ~= "" and File(M.cfg.bgMusicPath).exists() then
        M.updateProgress(97, "Adding background music (3s intro, auto-ducking, 3s outro)...", false)
        M.mixVoiceWithBgMusic(S.cleanVoiceWavPath, M.cfg.bgMusicPath, function(okMix, pathOrErr, mixedDur)
            if okMix then
                S.generatedAudioPath = pathOrErr
                M.onAudioReadyUI(mixedDur, labelPrefix .. " + Music")
            else
                M.logIssue("BgMusicMix", tostring(pathOrErr))
                M.onAudioReadyUI(durSec, labelPrefix)
            end
        end)
    else
        M.onAudioReadyUI(durSec, labelPrefix)
    end
end

function M.onAudioReadyUI(totalDurationSec, labelPrefix)
    local shortDur = M.formatDurationText(totalDurationSec)
    S.currentDurationStr = shortDur
    M.stopProgressTicker()
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
        if #cur > 0 and (#cur >= 110 or (chars + tChars) > 5500) then
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
                and (M.utf8CharCount(allTurns[#allTurns].text) + M.utf8CharCount(body)) < 5300 then
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
        local wouldExceedSize = (#curTurns > 0) and (#curTurns >= 110 or (curChars + tChars) > 5500)

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
    if totalChars <= 7000 then
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
        M.stopProgressTicker()
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
                table.insert(lines, "You are an award-winning scriptwriter. Write a masterclass, captivating, 100% authentic single-narrator script/story.")
                table.insert(lines, "Language: " .. lang .. " (use natural, idiomatic, expressive native phrasing — zero robotic or translated-sounding lines).")
                table.insert(lines, "Exact Style / Mood (100% STRICT): " .. M.cfg.singleStyle .. " — " .. M.getMoodActingInstruction(M.cfg.singleStyle) .. ".")
                table.insert(lines, "QUALITY RULE: Fully embody the selected mood from the very first sentence to the last (if Funny/Comedy: write genuinely hilarious setups and punchlines; if Islamic: deeply respectful, authentic and heartfelt; if Horror/Thriller: gripping suspense; if Storytelling: vivid imagery and emotional hooks).")
                table.insert(lines, "Target Length: approx " .. tostring(b.mins) .. " minute(s) (~" .. tostring(words) .. " words).")
                table.insert(lines, "STRICT RULES: Output ONLY clean spoken narration text matching the exact mood and language. No markdown stars (*), no headings (#), no brackets [], no emojis.")
            else
                table.insert(lines, "You are an award-winning broadcast scriptwriter. Write a masterclass, 100% realistic, gripping, natural conversation between " .. tostring(spkCount) .. " friends/hosts: " .. speakerRosterStr .. ".")
                table.insert(lines, "Language: " .. lang .. " (use natural, idiomatic native speech, real reactions, and authentic flow — zero robotic filler).")
                table.insert(lines, "Exact Mood / Style (100% STRICT): " .. M.cfg.bcMood .. " — " .. M.getMoodActingInstruction(M.cfg.bcMood) .. ".")
                table.insert(lines, "QUALITY RULE: Fully commit to the selected mood in every dialogue (if Funny/Comedy: real witty banter, jokes, and punchlines; if Islamic: deeply respectful, authentic, soulful; if Horror/Thriller: tense suspense; if Debate/News/Podcast: sharp, engaging, high-value points).")
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
            local nextCap = math.min(95, math.floor((bIdx / totalBatches) * 85) + 5)
            local batchLabel = (totalBatches > 1)
                and ("Writing script part " .. tostring(bIdx) .. "/" .. tostring(totalBatches) .. "...")
                or ("Writing " .. tostring(totalMins) .. " min script...")
            M.updateProgress(basePct, batchLabel, false)
            M.startProgressTicker(myJobId, basePct, nextCap, 1400, batchLabel)

            local payload = {
                contents = { { role = "user", parts = { { text = buildBatchPrompt(bIdx) } } } }
            }
            if useFastThinking then
                payload.generationConfig = { thinkingConfig = { thinkingBudget = 0 } }
            end

            local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. curModel .. ":generateContent?key=" .. curKey

            local okS, errS = M.httpPost(url, cjson.encode(payload), headers, function(code, content)
                M.stopProgressTicker()
                if isCanceled() then return end

                if code == 400 and useFastThinking then
                    M.delay(100, function() runBatch(bIdx, modelIdx, curKey, false, keyRetries) end)
                    return
                end

                if code == 429 or code == 503 or code == 500 or code == -1 or code == 404 then
                    local errTxt = tostring(M.extractApiError(content) or "Busy")
                    M.logIssue("ScriptBatch" .. tostring(bIdx), "ScriptModel " .. curModel .. " HTTP " .. tostring(code) .. ": " .. errTxt)
                    local isZeroLimit = errTxt:find("limit: 0", 1, true) ~= nil
                    if not isZeroLimit then
                        local altKey = M.getAlternateApiKey(curKey)
                        if altKey and keyRetries < 4 then
                            M.updateProgress(basePct, "Key busy (HTTP " .. tostring(code) .. "), switching API key...", false)
                            M.delay(200, function() runBatch(bIdx, modelIdx, altKey, useFastThinking, keyRetries + 1) end)
                            return
                        end
                    end
                    if modelIdx < #models then
                        local nextM = models[modelIdx + 1]
                        M.updateProgress(basePct, "Switching script model to " .. tostring(nextM) .. "...", false)
                        M.delay(200, function() runBatch(bIdx, modelIdx + 1, curKey, true, 0) end)
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
        M.stopProgressTicker()
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

    local baseStyle = M.getMoodActingInstruction(style)

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
        M.finalizeMergedVoice(durOrErr, "Audio")
    end

    local function processChunk(partIdx, ttsIdx, modeIdx, curKey, keyRetries, sameModelRetried)
        if isCanceled() then return end
        local curModel = ttsQueue[ttsIdx]
        if not curModel then
            stopOnError("Failed at Part " .. tostring(partIdx) .. "/" .. tostring(totalParts) .. ". Check Report Issue.")
            return
        end

        local doneBefore = partIdx - 1
        local pct = math.max(5, math.floor((doneBefore / totalParts) * 90))
        local nextCap = math.min(90, math.floor((partIdx / totalParts) * 90) - 5)
        if nextCap < pct + 5 then nextCap = math.min(90, pct + 15) end
        local partLabel = "Audio Part " .. tostring(partIdx) .. "/" .. tostring(totalParts) .. " generating..."
        M.updateProgress(pct, partLabel, partIdx == 1 and modeIdx == 1 and keyRetries == 0)
        M.startProgressTicker(myJobId, pct, nextCap, 1800, partLabel)

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

        local stylePrompt = "CRYSTAL-CLEAR STUDIO AUDIO (zero noise, crisp voice): " .. baseStyle .. ". Language: " .. lang .. ". " .. continuityLock

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
            M.stopProgressTicker()
            if isCanceled() then return end

            if code == 400 and modeIdx < 4 then
                M.delay(100, function() processChunk(partIdx, ttsIdx, modeIdx + 1, curKey, keyRetries, sameModelRetried) end)
                return
            end

            if code == 429 or code == 503 or code == 500 or code == -1 or code == 404 then
                M.logIssue("SinglePart" .. tostring(partIdx), "Model " .. curModel .. " HTTP " .. tostring(code) .. ": " .. tostring(M.extractApiError(content) or "Busy"))
                if not sameModelRetried then
                    M.updateProgress(pct, "Limit/busy on " .. curModel .. ". Rechecking in 5s...", false)
                    M.delay(5000, function() processChunk(partIdx, ttsIdx, modeIdx, curKey, keyRetries, true) end)
                    return
                end
                local altKey = M.getAlternateApiKey(curKey)
                if altKey and keyRetries < 4 then
                    M.updateProgress(pct, "Switching API key for Part " .. tostring(partIdx) .. "...", false)
                    M.delay(500, function() processChunk(partIdx, ttsIdx, modeIdx, altKey, keyRetries + 1, false) end)
                    return
                elseif ttsIdx < #ttsQueue then
                    M.updateProgress(pct, "Limit reached. Switching to next TTS model in 4s (Part " .. tostring(partIdx) .. ")...", false)
                    M.delay(4000, function() processChunk(partIdx, ttsIdx + 1, 1, M.getNextApiKey(), 0, false) end)
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
                    M.delay(50, function() processChunk(partIdx + 1, ttsIdx, modeIdx, M.getNextApiKey(), 0, false) end)
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
        processChunk(startIdx, 1, 1, firstKey, 0, false)
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
        M.stopProgressTicker()
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

        local function processBcPart(partIdx, ttsIdx, modeIdx, curKey, keyRetries, sameModelRetried)
            if isCanceled() then return end
            local curModel = ttsQueue[ttsIdx]
            if not curModel then
                stopOnError("Failed at Part " .. tostring(partIdx) .. "/" .. tostring(totalParts) .. ". Check Report Issue.")
                return
            end

            local pct = math.max(5, math.floor(((partIdx - 1) / totalParts) * 90))
            local nextCap = math.min(90, math.floor((partIdx / totalParts) * 90) - 5)
            if nextCap < pct + 5 then nextCap = math.min(90, pct + 15) end
            local partLabel = "Broadcast Part " .. tostring(partIdx) .. "/" .. tostring(totalParts) .. " generating..."
            M.updateProgress(pct, partLabel, partIdx == 1 and modeIdx == 1 and keyRetries == 0)
            M.startProgressTicker(myJobId, pct, nextCap, 1800, partLabel)

            local contNote = ""
            if partIdx > 1 and turnChunks[partIdx - 1] and #turnChunks[partIdx - 1] > 0 then
                local lastTurn = turnChunks[partIdx - 1][#turnChunks[partIdx - 1]]
                contNote = ", continuing seamlessly after '" .. string.sub(lastTurn.text or "", -180) .. "' with zero change in voice, pitch, or speed"
            end

            local exactMoodDesc = M.getMoodActingInstruction(mood)
            local s1Style = "CRYSTAL-CLEAR STUDIO VOICE (" .. v1 .. ") speaking in " .. lang
                .. ", 100% STRICT MOOD (" .. mood .. "): " .. exactMoodDesc
                .. ", crisp clean pronunciation, zero muffling, locked to identical voice identity, pitch, and tempo" .. contNote
            local s2Style = "CRYSTAL-CLEAR STUDIO VOICE (" .. v2 .. ") speaking in " .. lang
                .. ", 100% STRICT MOOD (" .. mood .. "): " .. exactMoodDesc
                .. ", crisp clean pronunciation, zero muffling, locked to identical voice identity, pitch, and tempo" .. contNote

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
                M.stopProgressTicker()
                if isCanceled() then return end

                if code == 400 and modeIdx < 4 then
                    M.delay(100, function() processBcPart(partIdx, ttsIdx, modeIdx + 1, curKey, keyRetries, sameModelRetried) end)
                    return
                end

                if code == 429 or code == 503 or code == 500 or code == -1 or code == 404 then
                    M.logIssue("Bc2Part" .. tostring(partIdx), "Model " .. curModel .. " HTTP " .. tostring(code) .. ": " .. tostring(M.extractApiError(content) or "Busy"))
                    if not sameModelRetried then
                        M.updateProgress(pct, "Limit/busy on " .. curModel .. ". Rechecking in 5s...", false)
                        M.delay(5000, function() processBcPart(partIdx, ttsIdx, modeIdx, curKey, keyRetries, true) end)
                        return
                    end
                    local altKey = M.getAlternateApiKey(curKey)
                    if altKey and keyRetries < 4 then
                        M.updateProgress(pct, "Switching API key for Part " .. tostring(partIdx) .. "...", false)
                        M.delay(500, function() processBcPart(partIdx, ttsIdx, modeIdx, altKey, keyRetries + 1, false) end)
                        return
                    elseif ttsIdx < #ttsQueue then
                        M.updateProgress(pct, "Limit reached. Switching to next TTS model in 4s (Part " .. tostring(partIdx) .. ")...", false)
                        M.delay(4000, function() processBcPart(partIdx, ttsIdx + 1, 1, M.getNextApiKey(), 0, false) end)
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
                        M.delay(50, function() processBcPart(partIdx + 1, ttsIdx, modeIdx, M.getNextApiKey(), 0, false) end)
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
            processBcPart(startIdx, 1, 1, firstKey, 0, false)
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
        M.finalizeMergedVoice(durOrErr, tostring(spkCount) .. "-Speaker Broadcast")
    end

    local function processBatch(partIdx, ttsIdx, modeIdx, curKey, keyRetries, sameModelRetried)
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
        local nextCap = math.min(90, math.floor((partIdx / totalParts) * 90) - 5)
        if nextCap < pct + 5 then nextCap = math.min(90, pct + 15) end
        local partLabel = "Broadcast Part " .. tostring(partIdx) .. "/" .. tostring(totalParts) .. " generating..."
        M.updateProgress(pct, partLabel, partIdx == 1 and modeIdx == 1 and keyRetries == 0)
        M.startProgressTicker(myJobId, pct, nextCap, 1800, partLabel)

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

            local exactMoodDesc = M.getMoodActingInstruction(mood)
            local styleA = "CRYSTAL-CLEAR STUDIO VOICE (" .. voiceA .. ") speaking in " .. lang
                .. ", 100% STRICT MOOD (" .. mood .. "): " .. exactMoodDesc
                .. ", crisp clean pronunciation, zero muffling, locked to identical voice identity, pitch, and tempo" .. contNote
            local styleB = "CRYSTAL-CLEAR STUDIO VOICE (" .. voiceB .. ") speaking in " .. lang
                .. ", 100% STRICT MOOD (" .. mood .. "): " .. exactMoodDesc
                .. ", crisp clean pronunciation, zero muffling, locked to identical voice identity, pitch, and tempo" .. contNote

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
            local exactMoodDesc = M.getMoodActingInstruction(mood)
            local stylePrompt = "CRYSTAL-CLEAR STUDIO VOICE (" .. voiceA .. ") speaking in " .. lang
                .. ", 100% STRICT MOOD (" .. mood .. "): " .. exactMoodDesc
                .. ", crisp clean pronunciation, zero muffling, locked to identical voice identity, pitch, and tempo" .. contNote
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
            M.stopProgressTicker()
            if isCanceled() then return end

            if code == 400 and modeIdx < 4 then
                M.delay(100, function() processBatch(partIdx, ttsIdx, modeIdx + 1, curKey, keyRetries, sameModelRetried) end)
                return
            end

            if code == 429 or code == 503 or code == 500 or code == -1 or code == 404 then
                M.logIssue("GroupPart" .. tostring(partIdx), "Model " .. curModel .. " HTTP " .. tostring(code) .. ": " .. tostring(M.extractApiError(content) or "Busy"))
                if not sameModelRetried then
                    M.updateProgress(pct, "Limit/busy on " .. curModel .. ". Rechecking in 5s...", false)
                    M.delay(5000, function() processBatch(partIdx, ttsIdx, modeIdx, curKey, keyRetries, true) end)
                    return
                end
                local altKey = M.getAlternateApiKey(curKey)
                if altKey and keyRetries < 4 then
                    M.updateProgress(pct, "Switching API key for Part " .. tostring(partIdx) .. "...", false)
                    M.delay(500, function() processBatch(partIdx, ttsIdx, modeIdx, altKey, keyRetries + 1, false) end)
                    return
                elseif ttsIdx < #ttsQueue then
                    M.updateProgress(pct, "Limit reached. Switching to next TTS model in 4s (Part " .. tostring(partIdx) .. ")...", false)
                    M.delay(4000, function() processBatch(partIdx, ttsIdx + 1, 1, M.getNextApiKey(), 0, false) end)
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
                    M.delay(50, function() processBatch(partIdx + 1, ttsIdx, modeIdx, M.getNextApiKey(), 0, false) end)
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
        processBatch(startIdx, 1, 1, firstKey, 0, false)
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
        padding = "12dp",
        layout_width = "fill",
        layout_height = "fill",
        {
            ListView,
            id = "voiceList",
            layout_width = "fill",
            layout_height = "0dp",
            layout_weight = "1",
            backgroundColor = "#F5F5F5",
            layout_marginBottom = "10dp"
        },
        {
            LinearLayout,
            orientation = "horizontal",
            layout_width = "fill",
            layout_height = "wrap",
            {
                Button,
                id = "cancelBtn",
                text = "CANCEL",
                layout_width = "0dp",
                layout_weight = "1",
                layout_height = "wrap",
                backgroundColor = "#757575",
                textColor = "#FFFFFF",
                padding = "12dp",
                layout_marginRight = "6dp"
            },
            {
                Button,
                id = "doneBtn",
                text = "DONE (" .. M.getVoiceDisplayName(tempVoice) .. ")",
                layout_width = "0dp",
                layout_weight = "1.2",
                layout_height = "wrap",
                backgroundColor = "#2E7D32",
                textColor = "#FFFFFF",
                padding = "12dp",
                layout_marginLeft = "6dp"
            }
        }
    }

    local dlg = LuaDialog(context)
    dlg.setTitle(title)
    dlg.setView(loadlayout(layout, views))
    dlg.setCancelable(true)

    pcall(function()
        local win = dlg.getWindow()
        if win then
            win.setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
        end
    end)

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
        local dispName = M.getVoiceDisplayName(pickedRaw)

        local firstVis = views.voiceList.getFirstVisiblePosition()
        local newItems = buildDisplay()
        local newAdapter = ArrayAdapter(context, android.R.layout.simple_list_item_1, newItems)
        views.voiceList.setAdapter(newAdapter)
        pcall(function() views.voiceList.setSelection(firstVis) end)
        pcall(function() views.doneBtn.setText("DONE (" .. dispName .. ")") end)

        M.speakOnly("Checked, " .. dispName)
        M.previewVoiceSample(pickedRaw)
    end

    views.cancelBtn.onClick = function()
        M.stopPreviewPlayer()
        dlg.dismiss()
    end

    views.doneBtn.onClick = function()
        M.stopPreviewPlayer()
        dlg.dismiss()
        if onConfirm then onConfirm(tempVoice) end
    end

    dlg.show()
end

-- ============================================================
-- Background Music Picker Dialog (Phone Storage Scan + [✓] + Instant Play + Bottom-Right DONE)
-- ============================================================
function M.scanDeviceAudioFiles()
    local results, seen = {}, {}
    local function addTrack(path, name)
        if not path or path == "" or seen[path] then return end
        local f = File(path)
        if not f.exists() or f.length() < 4000 then return end
        local lower = path:lower()
        if lower:match("%.mp3$") or lower:match("%.wav$") or lower:match("%.m4a$") or lower:match("%.aac$") or lower:match("%.ogg$") then
            seen[path] = true
            local disp = (name and name ~= "") and name or f.getName()
            table.insert(results, { name = disp, path = path })
        end
    end

    pcall(function()
        local resolver = context.getContentResolver()
        local MediaClass = luajava.bindClass("android.provider.MediaStore$Audio$Media")
        local proj = String({ "_data", "_display_name" })
        local cur = resolver.query(MediaClass.EXTERNAL_CONTENT_URI, proj, nil, nil, "date_modified DESC")
        if cur then
            local idxData = cur.getColumnIndex("_data")
            local idxName = cur.getColumnIndex("_display_name")
            local count = 0
            while cur.moveToNext() and count < 200 do
                local p = (idxData >= 0) and cur.getString(idxData) or nil
                local n = (idxName >= 0) and cur.getString(idxName) or nil
                if p then
                    addTrack(p, n)
                    count = count + 1
                end
            end
            cur.close()
        end
    end)

    local roots = {
        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC),
        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
        File(Environment.getExternalStorageDirectory(), "Music"),
        File(Environment.getExternalStorageDirectory(), "Download"),
        File(Environment.getExternalStorageDirectory(), "Audio")
    }
    for _, dir in ipairs(roots) do
        pcall(function()
            if dir and dir.exists() and dir.isDirectory() then
                local list = dir.listFiles()
                if list then
                    for i = 0, #list - 1 do
                        local item = list[i]
                        if item and item.isFile() then
                            addTrack(item.getAbsolutePath(), item.getName())
                        end
                    end
                end
            end
        end)
    end
    return results
end

function M.showBgMusicPickerDialog(onConfirm)
    local tracks = M.scanDeviceAudioFiles()
    if #tracks == 0 then
        M.speakOnly("No MP3 or audio music files found in phone storage.")
        return
    end

    local tempPath = M.cfg.bgMusicPath or ""
    local tempName = M.cfg.bgMusicName or ""
    local views = {}
    local layout = {
        LinearLayout,
        orientation = "vertical",
        padding = "12dp",
        layout_width = "fill",
        layout_height = "fill",
        {
            ListView,
            id = "musicList",
            layout_width = "fill",
            layout_height = "0dp",
            layout_weight = "1",
            backgroundColor = "#F5F5F5",
            layout_marginBottom = "10dp"
        },
        {
            LinearLayout,
            orientation = "horizontal",
            layout_width = "fill",
            layout_height = "wrap",
            {
                Button,
                id = "removeBtn",
                text = "REMOVE",
                layout_width = "0dp",
                layout_weight = "0.9",
                layout_height = "wrap",
                backgroundColor = "#C62828",
                textColor = "#FFFFFF",
                padding = "12dp",
                layout_marginRight = "4dp"
            },
            {
                Button,
                id = "cancelBtn",
                text = "CANCEL",
                layout_width = "0dp",
                layout_weight = "0.9",
                layout_height = "wrap",
                backgroundColor = "#757575",
                textColor = "#FFFFFF",
                padding = "12dp",
                layout_marginRight = "4dp"
            },
            {
                Button,
                id = "doneBtn",
                text = (tempName ~= "" and ("DONE (" .. tempName .. ")") or "DONE"),
                layout_width = "0dp",
                layout_weight = "1.2",
                layout_height = "wrap",
                backgroundColor = "#2E7D32",
                textColor = "#FFFFFF",
                padding = "12dp"
            }
        }
    }

    local dlg = LuaDialog(context)
    dlg.setTitle("Select Background Music (" .. tostring(#tracks) .. " files)")
    dlg.setView(loadlayout(layout, views))
    dlg.setCancelable(true)

    pcall(function()
        local win = dlg.getWindow()
        if win then
            win.setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
        end
    end)

    local function buildMusicDisplay()
        local items = {}
        local selIdx = 0
        for i, tr in ipairs(tracks) do
            if tr.path == tempPath then
                table.insert(items, "[✓] " .. tr.name)
                selIdx = i - 1
            else
                table.insert(items, tr.name)
            end
        end
        return items, selIdx
    end

    local items, selIdx = buildMusicDisplay()
    local adapter = ArrayAdapter(context, android.R.layout.simple_list_item_1, items)
    views.musicList.setAdapter(adapter)
    pcall(function() views.musicList.setSelection(selIdx) end)

    views.musicList.onItemClick = function(parent, v, pos, id)
        local tr = tracks[pos + 1]
        if not tr then return end
        tempPath = tr.path
        tempName = tr.name

        local firstVis = views.musicList.getFirstVisiblePosition()
        local newItems = buildMusicDisplay()
        local newAdapter = ArrayAdapter(context, android.R.layout.simple_list_item_1, newItems)
        views.musicList.setAdapter(newAdapter)
        pcall(function() views.musicList.setSelection(firstVis) end)
        pcall(function() views.doneBtn.setText("DONE (" .. tostring(tr.name) .. ")") end)

        M.speakOnly("Checked, " .. tostring(tr.name))
        M.playPreviewFile(tr.path)
    end

    views.removeBtn.onClick = function()
        M.stopPreviewPlayer()
        dlg.dismiss()
        if onConfirm then onConfirm("", "") end
    end

    views.cancelBtn.onClick = function()
        M.stopPreviewPlayer()
        dlg.dismiss()
    end

    views.doneBtn.onClick = function()
        M.stopPreviewPlayer()
        dlg.dismiss()
        if onConfirm then onConfirm(tempPath, tempName) end
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

    local fileName = getDefaultDownloadName() .. ".mp3"
    local shareUri = nil
    local lastErr = ""

    if Build.VERSION.SDK_INT >= 29 then
        local ok, err = pcall(function()
            local input = FileInputStream(sourceFile)
            local values = ContentValues()
            values.put("_display_name", fileName)
            values.put("mime_type", "audio/mpeg")
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
            sendIntent.setType("audio/mpeg")
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
    local fileName = safeBase .. ".mp3"
    local success = false
    local lastErr = ""

    local tempMp3 = File(M.baseStorageDir, "export_tmp_" .. os.time() .. ".mp3")
    local okExp = M.exportToMp3File(sourceFile.getAbsolutePath(), tempMp3)
    local exportSrc = (okExp and tempMp3.exists() and tempMp3.length() > 100) and tempMp3 or sourceFile

    if Build.VERSION.SDK_INT >= 29 then
        local ok, err = pcall(function()
            local input = FileInputStream(exportSrc)
            local values = ContentValues()
            values.put("_display_name", fileName)
            values.put("mime_type", "audio/mpeg")
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
            local input = FileInputStream(exportSrc)
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
    pcall(function() if tempMp3.exists() then tempMp3.delete() end end)

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
        M.updateProgress(0, "Saved to Phone Storage (Downloads) as " .. fileName .. "! Saved parts and box cleared.", true)
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


function M.showBgMusicSettingsDialog()
    local views = {}
    local layout = {
        LinearLayout,
        orientation = "vertical",
        padding = "18dp",
        layout_width = "fill",
        layout_height = "wrap",
        {
            Button,
            id = "duckVolBtn",
            text = "Music Vol During Voice: " .. tostring(M.cfg.bgDuckVol or 12) .. "%",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#3949AB",
            textColor = "#FFFFFF",
            padding = "12dp",
            layout_marginBottom = "10dp"
        },
        {
            Button,
            id = "normVolBtn",
            text = "Intro / Outro / Pause Music Vol: " .. tostring(M.cfg.bgNormalVol or 38) .. "%",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#5E35B1",
            textColor = "#FFFFFF",
            padding = "12dp",
            layout_marginBottom = "10dp"
        },
        {
            Button,
            id = "ioSecBtn",
            text = "Intro & Outro Time: " .. tostring(M.cfg.bgIntroOutroSec or 3) .. " Seconds",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#00897B",
            textColor = "#FFFFFF",
            padding = "12dp",
            layout_marginBottom = "10dp"
        },
        {
            Button,
            id = "voiceBoostBtn",
            text = "Voice Clarity Boost: " .. tostring(M.cfg.bgVoiceBoost or 100) .. "%",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#2E7D32",
            textColor = "#FFFFFF",
            padding = "12dp",
            layout_marginBottom = "10dp"
        },
        {
            Button,
            id = "autoDuckBtn",
            text = "Auto-Ducking: " .. ((M.cfg.bgAutoDuck ~= false) and "ON" or "OFF"),
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#E65100",
            textColor = "#FFFFFF",
            padding = "12dp",
            layout_marginBottom = "12dp"
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

    local dlg = LuaDialog(context)
    dlg.setTitle("BG Music & Auto-Ducking Settings")
    dlg.setView(loadlayout(layout, views))
    dlg.setCancelable(true)

    views.duckVolBtn.onClick = M.safe("pickDuckVol", function()
        local opts = { "5%", "10%", "12%", "15%", "20%", "25%", "30%", "40%" }
        M.showListPickerDialog("Music Volume During Voice", opts, nil, tostring(M.cfg.bgDuckVol or 12) .. "%", function(chosen)
            local n = tonumber(tostring(chosen):match("(%d+)")) or 12
            M.cfg.bgDuckVol = n
            M.saveSettings()
            views.duckVolBtn.setText("Music Vol During Voice: " .. tostring(n) .. "%")
            M.speakOnly("Music volume during voice set to " .. tostring(n) .. " percent")
        end)
    end)

    views.normVolBtn.onClick = M.safe("pickNormVol", function()
        local opts = { "20%", "30%", "38%", "50%", "60%", "75%" }
        M.showListPickerDialog("Intro / Outro / Pause Music Volume", opts, nil, tostring(M.cfg.bgNormalVol or 38) .. "%", function(chosen)
            local n = tonumber(tostring(chosen):match("(%d+)")) or 38
            M.cfg.bgNormalVol = n
            M.saveSettings()
            views.normVolBtn.setText("Intro / Outro / Pause Music Vol: " .. tostring(n) .. "%")
            M.speakOnly("Intro and outro music volume set to " .. tostring(n) .. " percent")
        end)
    end)

    views.ioSecBtn.onClick = M.safe("pickIoSec", function()
        local opts = { "0 Seconds", "2 Seconds", "3 Seconds", "4 Seconds", "5 Seconds" }
        M.showListPickerDialog("Intro & Outro Music Time", opts, nil, tostring(M.cfg.bgIntroOutroSec or 3) .. " Seconds", function(chosen)
            local n = tonumber(tostring(chosen):match("(%d+)")) or 3
            M.cfg.bgIntroOutroSec = n
            M.saveSettings()
            views.ioSecBtn.setText("Intro & Outro Time: " .. tostring(n) .. " Seconds")
            M.speakOnly("Intro and outro time set to " .. tostring(n) .. " seconds")
        end)
    end)

    views.voiceBoostBtn.onClick = M.safe("pickVoiceBoost", function()
        local opts = { "100% (Normal)", "115% (Clear Boost)", "130% (Loud)" }
        local cur = (M.cfg.bgVoiceBoost == 130) and "130% (Loud)" or ((M.cfg.bgVoiceBoost == 115) and "115% (Clear Boost)" or "100% (Normal)")
        M.showListPickerDialog("Voice Clarity Boost", opts, nil, cur, function(chosen)
            local n = tonumber(tostring(chosen):match("(%d+)")) or 100
            M.cfg.bgVoiceBoost = n
            M.saveSettings()
            views.voiceBoostBtn.setText("Voice Clarity Boost: " .. tostring(n) .. "%")
            M.speakOnly("Voice boost set to " .. tostring(n) .. " percent")
        end)
    end)

    views.autoDuckBtn.onClick = M.safe("toggleAutoDuck", function()
        M.cfg.bgAutoDuck = not (M.cfg.bgAutoDuck ~= false)
        M.saveSettings()
        local st = M.cfg.bgAutoDuck and "ON" or "OFF"
        views.autoDuckBtn.setText("Auto-Ducking: " .. st)
        M.speakOnly("Auto-ducking " .. st)
    end)

    views.backBtn.onClick = function() dlg.dismiss() end
    dlg.show()
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
            id = "bgSetBtn",
            text = "BG MUSIC & DUCKING SETTINGS",
            layout_width = "fill",
            layout_height = "wrap",
            backgroundColor = "#3949AB",
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
    views.bgSetBtn.onClick = M.safe("bgSettings", function() M.showBgMusicSettingsDialog() end)
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
                {
                    Button,
                    id = "bgMusicBtn",
                    text = "ADD BACKGROUND MUSIC (Optional: None)",
                    layout_width = "fill",
                    layout_height = "wrap",
                    backgroundColor = "#EDE7F6",
                    textColor = "#311B92",
                    textSize = 13,
                    padding = "10dp",
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
                    Button,
                    id = "applyBgBtn",
                    text = "APPLY / UPDATE BG MUSIC (Offline)",
                    layout_width = "fill",
                    layout_height = "wrap",
                    backgroundColor = "#512DA8",
                    textColor = "#FFFFFF",
                    textSize = 12,
                    padding = "8dp",
                    layout_marginBottom = "5dp"
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
        for i = 1, 4 do
            local vBtn = views["spkVoiceBtn_" .. i]
            if vBtn then
                vBtn.setText("Speaker " .. i .. " Voice: " .. M.getVoiceDisplayName(M.cfg.speakerVoices[i] or M.DEFAULT_SPK_VOICES[i]))
            end
        end
        if views.bgMusicBtn then
            if M.cfg.bgMusicPath and M.cfg.bgMusicPath ~= "" and M.cfg.bgMusicName ~= "" then
                views.bgMusicBtn.setText("BG Music: " .. tostring(M.cfg.bgMusicName))
            else
                views.bgMusicBtn.setText("ADD BACKGROUND MUSIC (Optional: None)")
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
            for i = 1, 4 do
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

    views.bgMusicBtn.onClick = M.safe("pickBgMusic", function()
        M.stopPreviewPlayer()
        M.showBgMusicPickerDialog(function(chosenPath, chosenName)
            M.cfg.bgMusicPath = chosenPath or ""
            M.cfg.bgMusicName = chosenName or ""
            M.saveSettings()
            syncOptionLabels()
            if chosenPath and chosenPath ~= "" then
                M.speakOnly("Background music selected: " .. tostring(chosenName))
            else
                M.speakOnly("Background music removed.")
            end
        end)
    end)

    views.applyBgBtn.onClick = M.safe("applyBgMusic", function()
        M.stopPreviewPlayer()
        M.applyBgMusicNow()
    end)

    -- Bind All 4 Speaker Name Inputs & Voice Picker Buttons
    for i = 1, 4 do
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
