-- ModMenu: the MODS screen. Schema-driven, styled after the game's Settings
-- screen (docs/game-style-spec.md; sizes in UMG units at 1440p = px / 1.333).
-- Layout: mod list on the left (scrolls), the selected mod's sections as the
-- tab bar, its rows in the middle, the description on the right.
-- Every change is written to the mod's settings.ini right away (RESET per row,
-- REVERT CHANGES per mod, RESTART NEEDED tag). Plain UMG only.
-- Loaded by main.lua with loadfile(...)(P, VIS).
local P, VIS = ...

local function lib(name)
    local ok, mod = pcall(dofile, P.dir .. "\\Scripts\\" .. name .. ".lua")
    if ok then return mod end
    P.log("%s not loaded: %s", name, tostring(mod))
    return nil
end
local INI, JSON = lib("modmenu_ini"), lib("modmenu_json")

-- Colours are LINEAR (UMG), taken from the game's Settings screen dump
-- (docs/game-style-spec.md).
local C = {
    backdrop  = { R = 0.004, G = 0.006, B = 0.005, A = 0.90 },
    rowBg     = { R = 0, G = 0, B = 0, A = 0.5 },        -- Image_Background
    valueBg   = { R = 1, G = 1, B = 1, A = 0.04 },       -- Image_BG (value area / choice text box)
    btnBg     = { R = 1, G = 1, B = 1, A = 0.039 },      -- WBP_MouseOnly_TextButton background
    btnHover  = { R = 1, G = 1, B = 1, A = 0.15 },       -- its hover overlay
    selected  = { R = 1, G = 1, B = 1, A = 0.12 },       -- the chosen On/Off half
    outline   = { R = 0.92, G = 0.92, B = 0.92, A = 1 },
    faint     = { R = 0.55, G = 0.55, B = 0.55, A = 0.28 },
    none      = { R = 0, G = 0, B = 0, A = 0 },
    white     = { R = 1, G = 1, B = 1, A = 1 },
    black     = { R = 0, G = 0, B = 0, A = 1 },
    tabBand   = { R = 0, G = 0, B = 0, A = 0.5 },
    tabSel    = { R = 0.0242, G = 0.2462, B = 0.0931, A = 1 },
    tabHover  = { R = 0.0232, G = 0.1195, B = 0.0561, A = 1 },
    tabText   = { R = 0.9047, G = 0.9047, B = 0.9047, A = 1 },
    titleGreen = { R = 0.1384, G = 0.3325, B = 0.2159, A = 1 },
    sliderBar = { R = 0.2346, G = 0.2502, B = 0.2462, A = 1 },
    sliderHot = { R = 1, G = 0.1765, B = 0.0353, A = 1 },
    orange    = { R = 1, G = 0.1765, B = 0.0353, A = 1 },
    hintBg    = { R = 0, G = 0, B = 0, A = 0.75 },   -- estimate (the dump had no hint bar); user: slightly transparent
    bad       = { R = 1, G = 0.12, B = 0.08, A = 1 },
}
-- sizes in UMG units, from the dump
local S = {
    title = 34, selOpen = 5, tab = 12, section = 16, name = 16, value = 16, desc = 16,
    hint = 12, hintKey = 12, groupH = 24, modName = 16, btnText = 16,
    edit = 14,    -- typed fields (colour, text): a bit under the value size
    rowH = 50, rowGap = 5, namePad = 7, valueW = 357, arrowW = 35, inner = 3,
    tabH = 50, tabMinW = 150, tabPad = 25, sliderW = 200, sliderRight = 60,
}
local DIM = 0.5          -- text opacity of a row that isn't hovered/focused
local SHEAR = -16
local KEYS = { "NONE", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
    "Insert", "Home", "End", "PageUp", "PageDown", "Delete" }
local L = {
    title = { 0.050, 0.050 },
    tabs  = { 0.205, 0.150, 0.39, 0.035 },
    mods  = { 0.050, 0.240, 0.135, 0.5795 },    -- ends 0.8195: a 0.0145 gap above the button
    menuBtn = { 0.050, 0.834, 0.135, 0.046 },    -- MOD MENU SETTINGS, its own thing under the list
    rows  = { 0.205, 0.240, 0.39, 0.64 },
    desc  = { 0.625, 0.262, 0.33, 0.30 },
    descTitle = { 0.625, 0.236 },                 -- the mod's full name above its description
}
local ASSETS = {
    line   = "/Game/DLCs/00080-STPATCH04/UI/Widgets/Textures/ReSkin_V1_Basics/1_Pixel_Line_Horizontal.1_Pixel_Line_Horizontal",
    circle = "/Game/UI/Assets/TextureAssets/char_circle.char_circle",
    keycap = "/Game/UI/Textures/Utility/SS_UI_Keyboard_PC_Empty.SS_UI_Keyboard_PC_Empty",
    emptySprite = "/Game/UI/Textures/UI_Tex_EmptySprite.UI_Tex_EmptySprite",
    ring   = "/Game/Prototype/Blueprints/CableBox/Maintenance_W_CableBox/Materials_Cables/2.2",   -- the slider's hover handle (sic)
}
local assetCache = {}
local function asset(key)
    local o = assetCache[key]
    if P.valid(o) then return o end
    o = StaticFindObject(ASSETS[key])
    if not P.valid(o) then pcall(function() o = LoadAsset(ASSETS[key]) end) end
    if P.valid(o) then assetCache[key] = o else o = nil end
    return o
end

---------------------------------------------------------------------------
-- widget helpers
---------------------------------------------------------------------------
local function new(cls, base) return P.newObj("/Script/UMG." .. cls, P.ui.tree, "ModMenu" .. base) end
local FONT = nil
local FONT_PATH = "/Game/UI/Assets/Fonts/Din_Pro/DINPro-CondMedium_Font.DINPro-CondMedium_Font"
local function findGameFont()
    if FONT and P.valid(FONT.obj) then return FONT end
    FONT = nil
    -- the game's font by path (always loaded in menus); borrowing from a menu label is the fallback
    local f = StaticFindObject(FONT_PATH)
    if not P.valid(f) then pcall(function() f = LoadAsset(FONT_PATH) end) end
    if P.valid(f) then FONT = { obj = f }; return FONT end
    for _, e in pairs(P.injected) do
        if P.valid(e.w) then
            for _, n in ipairs({ "Title_T", "Text_DisplayText" }) do
                local f = nil
                pcall(function() local t = e.w[n]; f = { obj = t.Font.FontObject } end)
                if f and f.obj and P.valid(f.obj) then FONT = f; return FONT end
            end
        end
    end
    return nil
end
local function applyFont(t, size, face)
    local f = findGameFont()
    if f then pcall(function() t.Font.FontObject = f.obj end) end
    pcall(function() t.Font.TypefaceFontName = FName(face or "MediumPro") end)
    pcall(function() t.Font.Size = size end)
    -- typed fields (EditableText) draw with the font in their style, not .Font
    if f then pcall(function() t.WidgetStyle.Font.FontObject = f.obj end) end
    pcall(function() t.WidgetStyle.Font.TypefaceFontName = FName(face or "MediumPro") end)
    pcall(function() t.WidgetStyle.Font.Size = size end)
end
local function setColor(t, color) pcall(function() t:SetColorAndOpacity({ SpecifiedColor = color, ColorUseRule = 0 }) end) end
local function setText(t, s) pcall(function() t:SetText(FText(s)) end) end
local function setOpacity(w, a) pcall(function() w:SetRenderOpacity(a) end) end
local function text(s, size, color, wrap, face)
    if type(size) ~= "number" then P.log("FAILED text %q has no font size", tostring(s)) end   -- (the sims fail on FAILED)
    local t = new("TextBlock", "Text")
    applyFont(t, size, face)
    setColor(t, color or C.white)
    setText(t, s)
    if wrap then pcall(function() t:SetAutoWrapText(true) end) end
    pcall(function() t:SetVisibility(VIS.HitTestInvisible) end)
    return t
end
local function border(color, l, t_, r, b)
    local bd = new("Border", "Border")
    pcall(function() bd:SetBrushColor(color) end)
    pcall(function() bd:SetPadding({ Left = l or 0, Top = t_ or 0, Right = r or 0, Bottom = b or 0 }) end)
    pcall(function() bd:SetVisibility(VIS.SelfHitTestInvisible) end)
    return bd
end
local function outline(color, thick)
    thick = thick or 1
    local ov = new("Overlay", "Outline")
    local lines = {}
    for _, e in ipairs({ { 0, 1, nil, thick }, { 0, 3, nil, thick }, { 1, 0, thick, nil }, { 3, 0, thick, nil } }) do
        local b = border(color)
        local sz = new("SizeBox", "Line")
        if e[3] then pcall(function() sz:SetWidthOverride(e[3]) end) end
        if e[4] then pcall(function() sz:SetHeightOverride(e[4]) end) end
        sz:SetContent(b)
        local sl = ov:AddChildToOverlay(sz)
        pcall(function() sl:SetHorizontalAlignment(e[1]); sl:SetVerticalAlignment(e[2]) end)
        lines[#lines + 1] = b
    end
    pcall(function() ov:SetVisibility(VIS.HitTestInvisible) end)
    local o = { w = ov }
    function o.set(c) for _, b in ipairs(lines) do pcall(function() b:SetBrushColor(c) end) end end
    return o
end
local function contentIn(bd, w, h, v)
    local s = P.callm(bd, "SetContent", w)
    if s then pcall(function() s:SetHorizontalAlignment(h or 0); s:SetVerticalAlignment(v or 0) end) end
    pcall(function() bd:SetHorizontalAlignment(h or 0); bd:SetVerticalAlignment(v or 0) end)
    return s
end
local function sized(w, width, height)
    local sz = new("SizeBox", "Size")
    if width then pcall(function() sz:SetWidthOverride(width) end) end
    if height then pcall(function() sz:SetHeightOverride(height) end) end
    sz:SetContent(w)
    return sz
end
local function shear(w, deg)
    pcall(function() w:SetRenderTransform({ Translation = { X = 0, Y = 0 }, Scale = { X = 1, Y = 1 }, Shear = { X = deg, Y = 0 }, Angle = 0 }) end)
end
local function catcher()
    local b = new("Button", "Catcher")
    pcall(function() b:SetRenderOpacity(0) end)
    pcall(function() b:SetVisibility(VIS.Visible) end)
    pcall(function() b.IsFocusable = false end)
    pcall(function() b:SetCursor(9) end)                -- EMouseCursor::Hand
    return b
end
local function align(slot, h, v) pcall(function() slot:SetHorizontalAlignment(h or 0); slot:SetVerticalAlignment(v or 0) end) end
local function grow(slot) pcall(function() slot:SetSize({ SizeRule = 1, Value = 1 }) end) end
local function pad(slot, l, t_, r, b) pcall(function() slot:SetPadding({ Left = l or 0, Top = t_ or 0, Right = r or 0, Bottom = b or 0 }) end) end
local function place(w, r, alignX, alignY)
    local s = P.callm(P.ui.canvas, "AddChildToCanvas", w)
    P.try("place", function()
        s:SetAnchors({ Minimum = { X = r[1], Y = r[2] }, Maximum = { X = r[1] + (r[3] or 0), Y = r[2] + (r[4] or 0) } })
        s:SetOffsets({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
        s:SetAlignment({ X = alignX or 0, Y = alignY or 0 })
        if not r[3] then s:SetAutoSize(true) end
    end)
    return s
end
local function divider()
    local d = border(C.divider)
    return sized(d, 1.5, nil)
end
local function clickable(btn, t)
    t.btn, t.pressed, t.hovered = btn, false, false
    P.ui.buttons[#P.ui.buttons + 1] = t
    return t
end

---------------------------------------------------------------------------
-- data: mods, schemas, row specs
---------------------------------------------------------------------------
-- Every folder in Mods is listed (except "shared", UE4SS's library folder).
-- Existence checks use io.open: the directory tree's names are case-sensitive,
-- Windows isn't.
local function exists(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end
P.exists = exists
function P.modsDir() return (P.dir:gsub("[/\\][^/\\]+$", "")) end
-- Mods\mods.txt: "Name : 1" lines (UE4SS's own list); lower-case name -> true/false
function P.readModsTxt()
    local out = {}
    local f = io.open(P.modsDir() .. "\\mods.txt", "rb")
    if not f then return out end
    for ln in f:lines() do
        local n, v = ln:match("^%s*([^;:]-)%s*:%s*(%d)")
        if n and n ~= "" then out[n:lower()] = (v == "1") end
    end
    f:close()
    return out
end
-- on/off as UE4SS sees it: "Name : 1" in mods.txt, or an enabled.txt in the
-- folder. Which switch the mod uses: enabled.txt if it has one, else mods.txt.
function P.modState(name, modsTxt)
    local listed = (modsTxt or P.readModsTxt())[name:lower()]
    local has = exists(P.modsDir() .. "\\" .. name .. "\\enabled.txt")
    local switch = has and "enabled.txt" or (listed ~= nil and "mods.txt") or "enabled.txt"
    return (listed == true) or has, switch
end
-- what the mods that come with UE4SS do (shown as their description); the two
-- usually installed also get a "(UE4SS)" display name and sort after other mods
local BUILTIN_TITLE = { keybinds = "(UE4SS) Keybinds", bpml_genericfunctions = "(UE4SS) BPML Functions", allowmodsmod = "(UE4SS) AllowModsMod" }
local BUILTIN = {
    keybinds = "Developer hotkeys (dumps).",
    bpml_genericfunctions = "Helpers for Blueprint mods.",
    allowmodsmod = "Lets the game allow mods. Not needed for Lua mods.",
    bpmodloadermod = "Loads Blueprint (pak) mods from the LogicMods folder.",
    consolecommandsmod = "Extra console commands for modders.",
    consoleenablermod = "Turns on the in-game developer console.",
    cheatmanagerenablermod = "Turns on the game's cheat manager.",
    actordumpermod = "Developer tool: dumps actors to a file.",
    linetracemod = "Developer tool: line traces under the crosshair.",
    splitscreenmod = "Developer tool: split-screen test.",
    jsbluaprofilermod = "Developer tool: Lua profiler.",
}
local function readMods()
    local mods = {}
    local ok, dirs = pcall(IterateGameDirectories)
    local root = ok and dirs and dirs.Game and dirs.Game.Binaries and dirs.Game.Binaries.Win64
        and dirs.Game.Binaries.Win64.ue4ss and dirs.Game.Binaries.Win64.ue4ss.Mods
    if not root then P.log("mods folder not found"); return mods end
    local modsDir = P.modsDir()
    local modsTxt = P.readModsTxt()
    for name, d in pairs(root) do
        name = tostring(name)
        if type(d) == "table" and not name:find("^__") and name:lower() ~= "shared" then
            local dir = modsDir .. "\\" .. name
            local m = { name = name, dir = dir, problems = {}, notices = {}, schema = {} }
            -- what kind of mod (a folder UE4SS can't start is a problem).
            -- C++ mods: dlls\main.dll by UE4SS's docs, but some ship as dlls\<Name>.dll
            local function hasDll(t)
                for k, sub in pairs(type(t) == "table" and t or {}) do
                    if tostring(k):lower() == "dlls" and type(sub) == "table" then
                        for _, f in pairs(sub.__files or {}) do
                            if type(f) == "table" and tostring(f.__name or ""):lower():find("%.dll$") then return true end
                        end
                    end
                end
                return false
            end
            if exists(dir .. "\\Scripts\\main.lua") then m.kind = "Lua"
            elseif exists(dir .. "\\dlls\\main.dll") or hasDll(d) then m.kind = "C++"
            else
                local inner = nil
                for sub, sd in pairs(d) do
                    sub = tostring(sub)
                    if type(sd) == "table" and not sub:find("^__") and (exists(dir .. "\\" .. sub .. "\\Scripts\\main.lua")
                        or exists(dir .. "\\" .. sub .. "\\dlls\\main.dll") or hasDll(sd)) then inner = sub end
                end
                if inner then
                    m.problems[#m.problems + 1] = "Installed one folder too deep: UE4SS looks for Mods\\" .. name
                        .. "\\Scripts, but the mod is in Mods\\" .. name .. "\\" .. inner
                        .. ". Move the contents of that inner folder up one level."
                else
                    m.problems[#m.problems + 1] = "Not a mod UE4SS can start: there's no Scripts\\main.lua (Lua mod) or dlls\\main.dll (C++ mod) in this folder."
                end
            end
            m.enabled, m.switch = P.modState(name, modsTxt)
            -- settings (optional)
            if exists(dir .. "\\settings.ini") and INI then
                local doc = INI.load(dir .. "\\settings.ini")
                if doc then
                    m.doc, m.path, m.hasSettings = doc, dir .. "\\settings.ini", true
                else
                    m.problems[#m.problems + 1] = "settings.ini exists but could not be read."
                end
            end
            if m.hasSettings and JSON then
                local paths = { dir .. "\\settings.schema.json", P.dir .. "\\schemas\\" .. name .. ".settings.schema.json" }
                for _, sp in ipairs(paths) do
                    if exists(sp) then
                        local t, err = JSON.load(sp)
                        if t then m.schema, m.schemaFrom = t, sp:find("\\schemas\\", 1, true) and "bundled with ModMenu" or "mod folder"; break end
                        m.problems[#m.problems + 1] = "settings.schema.json could not be read (" .. tostring(err) .. "); the settings are shown without it."
                        break
                    end
                end
            end
            m.doc = m.doc or INI.parse("")
            m.entries, m.openText = m.doc:entries(), m.doc:serialize()
            -- notices on the mod's page (problems first)
            for _, pr in ipairs(m.problems) do m.notices[#m.notices + 1] = { text = pr, color = C.bad } end
            -- the on/off switch: only for mods UE4SS starts via enabled.txt, that can
            -- start at all, and whose author didn't opt out ("allowToggle": false)
            m.toggleable = m.kind ~= nil and m.switch == "enabled.txt" and m.schema.allowToggle ~= false and name ~= P.selfName
            if not m.toggleable and m.kind and m.schema.allowToggle == false then
                -- (on needs no note: it's running)
                if not m.enabled then m.notices[#m.notices + 1] = { text = "Off (switch it on in the Mods folder)", color = C.white } end
            elseif not m.toggleable and not m.enabled then
                m.notices[#m.notices + 1] = { text = m.switch == "mods.txt" and "Off (in mods.txt)" or "Off (no enabled.txt)", color = C.white }
            end
            if not m.hasSettings then m.notices[#m.notices + 1] = { text = "No settings file", color = C.white } end
            local builtin = BUILTIN[name:lower()]
            m.builtin = builtin ~= nil
            if BUILTIN_TITLE[name:lower()] and not m.schema.title then m.schema.title = BUILTIN_TITLE[name:lower()] end
            m.about = m.schema.description or m.doc.description
                or builtin
                or ((m.kind and (m.kind .. " mod.") or "") .. (m.hasSettings and "" or " No settings."))
            -- ModMenu itself is only listed once it has settings of its own
            if name ~= P.selfName or m.hasSettings then mods[#mods + 1] = m end
            P.log("mod %s: %s, %s, %d settings, schema %s%s", name, m.kind or "not a mod", m.enabled and "on" or "off",
                #m.entries, m.schemaFrom or "none", #m.problems > 0 and (", " .. #m.problems .. " problem(s)") or "")
        end
    end
    -- switched-on mods with settings first (the screen opens on the first one),
    -- then the other switched-on ones, then everything that's off; by name within
    local function rank(m) return (m.name == P.selfName and 9) or (m.enabled == false and 3) or (m.builtin and 2) or (m.hasSettings and 0) or 1 end
    table.sort(mods, function(x, y)
        if rank(x) ~= rank(y) then return rank(x) < rank(y) end
        return (x.schema.title or x.name):lower() < (y.schema.title or y.name):lower()
    end)
    return mods
end
local function pretty(s) return (s:gsub("(%l)(%u)", "%1 %2")) end
local function decimals(step)
    local d = tostring(step):match("%.(%d+)$")
    return d and #d or 0
end
local function spec(e, sch)
    sch = sch or {}
    if sch.hidden then return nil end
    local v = e.value or ""
    local lv = v:lower()
    local s = { key = e.key, value = v, label = sch.label or pretty(e.key),
        desc = sch.description or e.comment or "", type = sch.type }
    if not s.type then
        if lv == "true" or lv == "false" then s.type = "toggle"
        elseif v:match("^%x%x%x%x%x%x$") then s.type = "color"
        elseif e.key:match("Key$") then s.type = "key"
        elseif tonumber(v) then s.type = "number"
        else s.type = "text" end
    end
    if s.type == "number" then
        local n = tonumber(v) or 0
        s.min = sch.min or 0
        s.max = sch.max or ((n <= 1 and 1) or (n <= 100 and 100) or n * 2)
        s.step = sch.step or ((s.max <= 1 and 0.01) or 1)
        s.unit = sch.unit
    elseif s.type == "choice" then
        s.options, s.labels = sch.options or { v }, sch.labels or {}
    elseif s.type == "multi" then
        s.options, s.none, s.labels = sch.options or {}, sch.none or "off", sch.labels or {}
    elseif s.type == "key" then
        s.options = KEYS
    end
    s.advanced = sch.advanced
    s.group = sch.group or e.group
    if sch.default ~= nil then s.default = tostring(sch.default) end
    -- "readonly": shown (dimmed) but not changeable from the menu; "note" says why
    if sch.mainMenuOnly and P.mapName and P.mapName() ~= "mainmenu" then
        sch = setmetatable({ readonly = true, note = sch.note or "Can only be changed from the main menu." }, { __index = sch })
    end
    if sch.readonly then
        s.type, s.default = "readonly", nil
        if sch.note then s.desc = (s.desc ~= "" and (s.desc .. "\n\n") or "") .. sch.note end
    end
    return s
end
-- a mod's settings grouped into sections (the tab bar)
local function sectionsOf(mod)
    local out, byName = {}, {}
    local sch = mod.schema.settings or {}
    local hidden = 0
    local dbgSpecs = {}       -- "debug": true settings live in the DEBUG tab (shown only with Debug on)
    for _, e in ipairs(mod.doc:entries()) do          -- current values (not the ones read at open)
        local sp = spec(e, sch[e.key])
        if not sp then hidden = hidden + 1
        elseif type(sch[e.key]) == "table" and sch[e.key].debug == true then dbgSpecs[#dbgSpecs + 1] = sp
        else
            local sec = e.section or "General"
            if sp.advanced == true then sec = "Advanced" elseif sp.advanced == false then sec = "General" end
            if not byName[sec] then byName[sec] = { name = sec, specs = {} }; out[#out + 1] = byName[sec] end
            table.insert(byName[sec].specs, sp)
        end
    end
    -- notices (problems, off, no settings) open the first section
    if mod.notices and #mod.notices > 0 then
        if #out == 0 then out[1] = { name = "General", specs = {} } end
        for i = #mod.notices, 1, -1 do
            local n = mod.notices[i]
            table.insert(out[1].specs, 1, { type = "notice", key = "__notice" .. i, label = n.text, color = n.color, desc = n.text, value = "" })
        end
    end
    if mod.toggleable then
        if #out == 0 then out[1] = { name = "General", specs = {} } end
        table.insert(out[1].specs, #(mod.problems or {}) + 1, { type = "toggle", key = "__enabled", label = "Enabled",
            value = mod.enabled and "true" or "false",
            desc = "Switch this mod on or off (renames its enabled.txt). Takes effect after a restart.",
            onSet = function(v) return P.setEnabled(mod, v == "true") end })
    end
    local ds = P.debugSection and P.debugSection(mod, dbgSpecs)
    if ds then out[#out + 1] = ds end
    return out, hidden
end

---------------------------------------------------------------------------
-- rows: [outline [name (dark) | value area (lighter, 357 wide)]]
---------------------------------------------------------------------------
local changed      -- defined below (saving)
-- (an empty FText doesn't clear the text here, so "" becomes a space)
-- the heading above the description: a mod's full name, upper case
function P.setDescTitle(m)
    local ui = P.ui
    if ui and ui.descTitle then setText(ui.descTitle, m and string.upper(m.schema.title or m.name) or " ") end
end
local function setDescription(s) if P.ui and P.ui.desc then setText(P.ui.desc, (s and s ~= "") and s or " ") end end
-- A row (the game's recipe): 50 high, black 50 % background, name at padding 7
-- (50 % opacity until hovered), a faint outline (white while hovered), and a
-- 357-wide value area on the right made of parts. Rows are 5 apart.
local function rowShell(list, s)
    local row = { s = s, value = s.value, hoverN = 0, texts = {}, dim = {} }
    local size = new("SizeBox", "RowSize")
    pcall(function() size:SetHeightOverride(S.rowH) end)
    local ov = new("Overlay", "RowOv")
    size:SetContent(ov)
    align(ov:AddChildToOverlay(border(C.rowBg)))
    row.outline = outline(C.faint)
    align(ov:AddChildToOverlay(row.outline.w))
    local hb = new("HorizontalBox", "RowH")
    align(ov:AddChildToOverlay(hb))
    row.nameOv = new("Overlay", "NameOv")
    row.nameT = text(s.label, S.name, C.white)
    setOpacity(row.nameT, DIM)
    row.texts[#row.texts + 1] = row.nameT
    local nts = row.nameOv:AddChildToOverlay(row.nameT); align(nts, 1, 2); pad(nts, S.namePad, 0, 0, 0)
    local ns = hb:AddChildToHorizontalBox(row.nameOv); grow(ns); align(ns)
    row.vbg = border(C.none)
    row.valueHB = new("HorizontalBox", "ValueH")
    contentIn(row.vbg, row.valueHB)
    local vs = hb:AddChildToHorizontalBox(sized(row.vbg, S.valueW, nil)); align(vs)
    local s2 = list:AddChild(size)
    pad(s2, 0, 0, 0, S.rowGap)
    return row
end
local function rowHover(row, hv)
    row.hoverN = math.max(0, row.hoverN + (hv and 1 or -1))
    local on = row.hoverN > 0
    row.outline.set(on and C.outline or C.faint)
    for _, t in ipairs(row.texts) do setOpacity(t, on and 1 or (row.dim[t] or DIM)) end
    if on then setDescription(row.clash and ((row.s.desc ~= "" and (row.s.desc .. "\n\n") or "") .. row.clash) or row.s.desc) end
    if row.onHover and on ~= row.hoverOn then row.hoverOn = on; row.onHover(on) end
    if row.updateReset then row.updateReset() end
end
local function nameArea(row)
    local cat = catcher()
    pcall(function() cat:SetCursor(1) end)
    align(row.nameOv:AddChildToOverlay(cat))
    local c = clickable(cat, { click = function() end, hover = function(hv) rowHover(row, hv) end, row = row })
    if row.s.default ~= nil then
        local rov = new("Overlay", "Reset")
        local rbg = border(C.btnBg)
        align(rov:AddChildToOverlay(rbg))
        local rt = text("RESET", 11, C.white)
        local rts = rov:AddChildToOverlay(rt); align(rts, 2, 2); pad(rts, 10, 0, 10, 0)
        local hot = border(C.none)
        align(rov:AddChildToOverlay(hot))
        local rcat = catcher()
        align(rov:AddChildToOverlay(rcat))
        local box = new("SizeBox", "ResetSize")
        pcall(function() box:SetHeightOverride(26) end)
        box:SetContent(rov)
        local bs = row.nameOv:AddChildToOverlay(box); align(bs, 3, 2); pad(bs, 0, 0, 10, 0)
        pcall(function() box:SetVisibility(VIS.Collapsed) end)
        row.updateReset = function()
            local show = row.hoverN > 0 and tostring(row.value) ~= row.s.default
            pcall(function() box:SetVisibility(show and VIS.SelfHitTestInvisible or VIS.Collapsed) end)
        end
        clickable(rcat, { row = row, click = function()
            changed(row, row.s.default)
            if row.slider then pcall(function() row.slider:SetValue(tonumber(row.s.default) or 0) end) end
            if row.edit then pcall(function() row.edit:SetText(FText(row.s.default)) end); row.typed = row.s.default end
        end, hover = function(hv)
            pcall(function() hot:SetBrushColor(hv and C.btnHover or C.none) end)
            rowHover(row, hv)
        end })
    end
    return c
end
-- a part of the value area: [bg][content][hover overlay][click area]
--   width nil = share the space; quiet = no click, no hover highlight
local function part(row, content, width, onClick, base, quiet, padR)
    local ov = new("Overlay", "Part")
    local bg = border(base or C.btnBg)
    align(ov:AddChildToOverlay(bg))
    align(ov:AddChildToOverlay(content), 2, 2)
    local hot = border(C.none)
    align(ov:AddChildToOverlay(hot))
    local cat = catcher()
    align(ov:AddChildToOverlay(cat))
    local holder = width and sized(ov, width, nil) or ov
    local sl = row.valueHB:AddChildToHorizontalBox(holder)
    if not width then grow(sl) end
    align(sl)
    if padR then pad(sl, 0, 0, padR, 0) end
    local p = { bg = bg }
    if quiet then pcall(function() cat:SetCursor(1) end) end
    p.click = clickable(cat, { click = onClick or function() end, row = row, hover = function(hv)
        if not quiet then pcall(function() hot:SetBrushColor(hv and C.btnHover or C.none) end) end
        rowHover(row, hv)
    end })
    function p.setBase(c) pcall(function() bg:SetBrushColor(c) end) end
    return p
end
local function gap(row, w)
    align(row.valueHB:AddChildToHorizontalBox(sized(border(C.none), w or S.inner, nil)), 0, 0)
end
-- Saving: every change goes straight to the mod's settings.ini (bundled per
-- mod, 0.3 s). "Restart needed" = the file differs from what the mods read at
-- game start (P.loadText, taken when this code loaded). Live mods get a
-- shared-variable ping instead.
local function curMod() return P.ui and P.ui.mods[P.ui.modIndex] end
-- "applies": per setting, else the schema's top level, else "restart"
local function appliesOf(mod, key)
    local sch = (mod.schema.settings or {})[key]
    return (type(sch) == "table" and sch.applies) or mod.schema.applies or "restart"
end
-- restart needed = a restart-only setting differs from what the mod read at game start
local function needsRestart(mod)
    local was = P.loadEnabled and P.loadEnabled[mod.name]
    if was ~= nil and mod.enabled ~= nil and was ~= mod.enabled then return true end
    local base = P.loadText and P.loadText[mod.name]
    if not base or not INI then return false end
    if mod.baseText ~= base then mod.baseText, mod.baseDoc = base, INI.parse(base) end
    for _, e in ipairs(mod.doc:entries()) do
        if appliesOf(mod, e.key) ~= "live" and tostring(mod.baseDoc:get(e.key)) ~= tostring(e.value) then return true end
    end
    return false
end
local function changedSinceOpen(mod) return mod.doc:serialize() ~= mod.openText end
-- Key clashes: the same key in two switched-on mods (or ModMenu's own F10).
local function isKeySetting(mod, key)
    local sch = (mod.schema.settings or {})[key]
    if type(sch) == "table" and sch.type then return sch.type == "key" end
    return key:match("Key$") ~= nil
end
-- -> list of { mod = other mod, key = its setting } using this mod's key
function P.keyClashes(mod, key)
    local ui = P.ui
    local v = tostring(mod.doc:get(key) or ""):upper()
    if v == "" or v == "NONE" or mod.enabled == false then return {} end
    local out = {}
    if v == tostring(P.KEY):upper() and mod.name ~= P.selfName then out[#out + 1] = { name = "Will's Mod Menu", key = "open the menu" } end
    for _, m in ipairs(ui and ui.mods or {}) do
        if m.enabled ~= false then
            for _, e in ipairs(m.doc:entries()) do
                -- another key of any mod, this one included (two of its own keys on one key)
                if (m ~= mod or e.key:lower() ~= key:lower()) and isKeySetting(m, e.key) and tostring(e.value):upper() == v then
                    local sch = (m.schema.settings or {})[e.key]
                    local label = (type(sch) == "table" and sch.label) or pretty(e.key)
                    out[#out + 1] = { name = (m == mod) and "this mod" or (m.schema.title or m.name), key = e.key, label = label }
                end
            end
        end
    end
    return out
end
function P.clashText(mod, key)
    local c = P.keyClashes(mod, key)
    if #c == 0 then return nil end
    local parts = {}
    for _, x in ipairs(c) do parts[#parts + 1] = x.name .. " (" .. (x.label or x.key) .. ")" end
    return "Key clash: " .. tostring(mod.doc:get(key)):upper() .. " is also used by " .. table.concat(parts, ", ") .. "."
end
local function modTags(m)
    local tags, color = {}, C.orange
    if #(m.problems or {}) > 0 then tags[#tags + 1] = "PROBLEM"; color = C.bad end
    if m.enabled == false then tags[#tags + 1] = "OFF" end
    for _, e in ipairs(m.doc:entries()) do
        if isKeySetting(m, e.key) and P.clashText(m, e.key) then tags[#tags + 1] = "KEY CLASH"; break end
    end
    if needsRestart(m) then tags[#tags + 1] = "RESTART NEEDED" end
    if #tags == 1 and tags[1] == "OFF" then color = { R = 0.6, G = 0.6, B = 0.6, A = 1 } end
    return table.concat(tags, " / "), color
end
-- On/off through UE4SS's enabled.txt: off = rename it to enabled.txt.off, on =
-- rename it back (or create an empty one). Nothing is deleted, except an empty
-- leftover enabled.txt.off that would block the rename. The state is read back.
function P.setEnabled(mod, on)
    local txt, off = mod.dir .. "\\enabled.txt", mod.dir .. "\\enabled.txt.off"
    local ok, err = true, nil
    if on and not exists(txt) then
        if exists(off) then ok, err = os.rename(off, txt)
        else local f = io.open(txt, "wb"); if f then f:close() else ok, err = false, "could not create enabled.txt" end end
    elseif not on and exists(txt) then
        if exists(off) then
            local f = io.open(off, "rb"); local size = f and #(f:read("a") or "x") or 1; if f then f:close() end
            if size == 0 then os.remove(off) end
        end
        ok, err = os.rename(txt, off)
    end
    mod.enabled = P.modState(mod.name)
    P.log("%s switched %s: %s", mod.name, on and "on" or "off", (mod.enabled == on) and "ok" or ("FAILED " .. tostring(err)))
    for k, m in ipairs(P.ui and P.ui.mods or {}) do
        if m == mod and P.ui.modWidgets[k] then P.ui.modWidgets[k].off = (mod.enabled == false) end
    end
    return mod.enabled == on
end
-- every status (mod list tags, clash marks on rows, REVERT) is worked out here
function P.refreshStatus()
    local ui = P.ui
    if not ui then return end
    for k, m in ipairs(ui.mods) do
        local w = ui.modWidgets and ui.modWidgets[k]
        if w and w.tag then
            local txt, col = modTags(m)
            if w.tagText ~= txt then
                w.tagText = txt
                w.off = (m.enabled == false)
                setOpacity(w.t, (ui.modIndex == k or w.hovered) and 1 or (w.off and DIM * 0.6 or DIM))
                setText(w.tag, txt); setColor(w.tag, col)
                pcall(function() w.tag:SetVisibility(txt ~= "" and VIS.HitTestInvisible or VIS.Collapsed) end)
            end
        end
    end
    local cm = curMod()
    for _, r in ipairs(ui.rows or {}) do
        if cm and r.s.type == "key" and r.nameT then
            r.clash = P.clashText(cm, r.s.key)
            setColor(r.nameT, r.clash and C.orange or C.white)
        end
    end
    local mod = curMod()
    if ui.revert then
        local show = mod and mod.path and changedSinceOpen(mod)
        pcall(function() ui.revert:SetVisibility(show and VIS.SelfHitTestInvisible or VIS.Collapsed) end)
    end
end
function P.saveSetting(mod, key, value)
    if not mod or not mod.path then return end
    mod.doc:set(key, value)
    mod.saveAt = os.clock() + 0.3
    P.refreshStatus()
end
function P.flushSaves(force)
    for _, mod in ipairs(P.ui and P.ui.mods or {}) do
        if mod.saveAt and mod.path and (force or os.clock() >= mod.saveAt) then
            mod.saveAt = nil
            -- @dev-begin
            -- (testing safety) keep the original file once, before the first save
            local bak = mod.path .. ".before-modmenu"
            local exists = io.open(bak, "rb")
            if exists then exists:close() else
                local orig = (P.loadText and P.loadText[mod.name]) or mod.openText
                local f = io.open(bak, "wb")
                if f then f:write(orig); f:close(); P.log("backup: %s", bak) end
            end
            -- @dev-end
            local ok, err = mod.doc:save(mod.path)
            P.log("saved %s: %s", mod.name, ok and "ok" or tostring(err))
            -- tell the mod (mods that apply settings live watch this; others ignore it).
            -- os.clock() never repeats in a game session, even across Ctrl+R.
            if ok and ModRef then
                pcall(function() ModRef:SetSharedVariable("ModMenu.changed." .. mod.name, os.clock()) end)
            end
        end
    end
end
function changed(row, v)
    local cm0 = curMod()
    if cm0 and cm0.name == P.selfName and row.s.key == "Debug" then
        row.value = v; row.show()
        P.saveSetting(cm0, row.s.key, v)
        P.showMod(P.ui.modIndex)              -- DEBUG tabs appear / go
        return
    end
    if row.s.onSet then
        local ok = row.s.onSet(v)
        row.value = ok and v or row.value
        row.show()
        P.refreshStatus()
        return
    end
    row.value = v
    row.show()
    if row.updateReset then row.updateReset() end
    P.log("row %s -> %s", row.s.key, tostring(v))
    P.saveSetting(curMod(), row.s.key, v)
end
local function optText(s)
    local t = text(s, S.btnText, C.white)
    return t
end

local builders = {}
function builders.toggle(list, s)
    local row = rowShell(list, s)
    nameArea(row)
    row.onT, row.offT = optText("On"), optText("Off")
    row.texts[#row.texts + 1] = row.onT; row.texts[#row.texts + 1] = row.offT
    row.onP = part(row, row.onT, nil, function() changed(row, "true") end)
    gap(row)
    row.offP = part(row, row.offT, nil, function() changed(row, "false") end)
    function row.show()
        local on = (row.value or ""):lower() == "true"
        row.onP.setBase(on and C.selected or C.btnBg); row.offP.setBase(on and C.btnBg or C.selected)
        -- the chosen half reads brighter; the other stays at the row's dim level
        row.dim[row.onT] = on and 0.85 or DIM; row.dim[row.offT] = on and DIM or 0.85
        local hot = row.hoverN > 0
        setOpacity(row.onT, hot and 1 or row.dim[row.onT]); setOpacity(row.offT, hot and 1 or row.dim[row.offT])
    end
    row.show()
    return row
end
local function cycle(row, dir)
    local opts = row.s.options
    if not opts or #opts == 0 then return end
    local i = 0
    for k, o in ipairs(opts) do if o:lower() == (row.value or ""):lower() then i = k end end
    if i == 0 then i = dir > 0 and 0 or 1 end
    changed(row, opts[(i - 1 + dir) % #opts + 1])
end
local function choiceRow(list, s)
    local row = rowShell(list, s)
    nameArea(row)
    row.valT = text(row.value, S.value, C.white)
    setOpacity(row.valT, DIM)
    row.texts[#row.texts + 1] = row.valT
    local lt, rt = optText("<"), optText(">")
    setOpacity(lt, 0.85); setOpacity(rt, 0.85)
    part(row, lt, S.arrowW, function() cycle(row, -1) end)
    gap(row)
    part(row, row.valT, nil, nil, C.valueBg, true)
    gap(row)
    part(row, rt, S.arrowW, function() cycle(row, 1) end, nil, nil, 1.5)
    function row.show()
        local shown = row.value
        if s.labels and s.labels[row.value] then shown = s.labels[row.value] end
        setText(row.valT, shown)
    end
    row.show()
    return row
end
builders.choice = choiceRow
builders.key = choiceRow
-- The game's slider style (WBP_Settings_SliderButton Slider_Value, from the
-- dump), rebuilt on our own slider. Never copied from a live game widget: in a
-- heist FindAllOf returns stale Settings sliders, and copying their style
-- struct crashed the game (2026-11-21).
local function brush(res, w, h, tint)
    return { DrawAs = 3, ImageSize = { X = w, Y = h }, ResourceObject = res,
        TintColor = { SpecifiedColor = tint, ColorUseRule = 0 } }
end
local function styleSlider(sl)
    local empty, circle = asset("emptySprite"), asset("circle")
    local st = nil
    pcall(function() st = sl.WidgetStyle end)
    if not st then return end
    pcall(function() st.NormalBarImage = brush(empty, 200, 7, C.white) end)
    -- white: the bar colour (orange on hover) tints it; an orange tint here made orange x orange = red
    pcall(function() st.HoveredBarImage = brush(empty, 7, 7, C.white) end)
    pcall(function() st.DisabledBarImage = brush(empty, 7, 7, { R = 0.5, G = 0.5, B = 0.5, A = 1 }) end)
    pcall(function() st.NormalThumbImage = brush(circle, 15, 15, C.white) end)
    pcall(function() st.HoveredThumbImage = brush(asset("ring") or circle, 20, 20, C.white) end)
    pcall(function() st.BarThickness = 5 end)
end
function builders.number(list, s)
    local row = rowShell(list, s)
    nameArea(row)
    pcall(function() row.vbg:SetBrushColor(C.valueBg) end)
    -- [value text][slider 200 x 50], right-aligned, 60 from the right edge
    local inner = new("HorizontalBox", "SliderH")
    local sl0 = row.valueHB:AddChildToHorizontalBox(inner); grow(sl0); align(sl0, 3, 2); pad(sl0, 0, 0, S.sliderRight, 0)
    row.valT = text(row.value, S.value, C.white)
    setOpacity(row.valT, DIM)
    row.texts[#row.texts + 1] = row.valT
    local vs = inner:AddChildToHorizontalBox(row.valT); align(vs, 1, 2); pad(vs, 5, 0, 5, 0)
    row.slider = new("Slider", "SliderBar")
    styleSlider(row.slider)
    -- the game's look: grey bar + grey dot; while the row is hovered an orange
    -- bar and an orange ring handle
    pcall(function() row.slider:SetSliderBarColor(C.sliderBar) end)
    pcall(function() row.slider:SetSliderHandleColor(C.sliderBar) end)
    row.onHover = function(on)
        pcall(function() row.slider:SetSliderBarColor(on and C.sliderHot or C.sliderBar) end)
        pcall(function() row.slider:SetSliderHandleColor(on and C.sliderHot or C.sliderBar) end)
        local ring = asset("ring")
        if ring then
            pcall(function() row.slider.WidgetStyle.NormalThumbImage = on and brush(ring, 20, 20, C.white) or brush(asset("circle"), 15, 15, C.white) end)
        end
    end
    pcall(function() row.slider:SetMinValue(s.min); row.slider:SetMaxValue(s.max) end)
    pcall(function() row.slider:SetStepSize(s.step) end)
    pcall(function() row.slider.MouseUsesStep = true end)
    pcall(function() row.slider.IsFocusable = false end)
    pcall(function() row.slider:SetVisibility(VIS.Visible) end)
    pcall(function() row.slider:SetCursor(9) end)
    local ss = inner:AddChildToHorizontalBox(sized(row.slider, S.sliderW, S.rowH)); align(ss, 0, 2)
    local dec = decimals(s.step)
    local function fmt(v) return dec > 0 and string.format("%." .. dec .. "f", v) or tostring(math.floor(v + 0.5)) end
    function row.show()
        setText(row.valT, row.value .. (s.unit and (" " .. s.unit) or ""))
        pcall(function() row.slider:SetValue(tonumber(row.value) or 0) end)
    end
    row.poll = function()
        local v = P.callm(row.slider, "GetValue")
        if type(v) == "number" then
            local nv = fmt(v)
            if nv ~= row.value then
                row.value = nv
                setText(row.valT, nv .. (s.unit and (" " .. s.unit) or ""))
                row.dirty = true
            end
        end
        local hv = P.callm(row.slider, "IsHovered") == true
        if hv ~= (row.sliderHover or false) then
            row.sliderHover = hv
            rowHover(row, hv)       -- (the orange look comes from row.onHover)
            if not hv and row.dirty then
                row.dirty = false
                P.log("row %s -> %s (slider)", s.key, row.value)
                P.saveSetting(curMod(), s.key, row.value)
                if row.updateReset then row.updateReset() end
            end
        end
    end
    row.show()
    return row
end
function builders.multi(list, s)
    local row = rowShell(list, s)
    nameArea(row)
    row.chips = {}
    local function selected()
        local set = {}
        for w in (row.value or ""):gmatch("[^,%s]+") do set[w:lower()] = true end
        return set
    end
    function row.show()
        local set = selected()
        local hot = row.hoverN > 0
        for _, ch in ipairs(row.chips) do
            local on = set[ch.opt:lower()] == true
            ch.p.setBase(on and C.selected or C.btnBg)
            row.dim[ch.t] = on and 0.85 or DIM
            setOpacity(ch.t, hot and 1 or row.dim[ch.t])
        end
    end
    for i, opt in ipairs(s.options) do
        if i > 1 then gap(row) end
        local t = optText((s.labels and s.labels[opt]) or opt)      -- shown name; the file gets opt
        row.texts[#row.texts + 1] = t
        local ch = { opt = opt, t = t }
        ch.p = part(row, t, nil, function()
            local set = selected()
            set[opt:lower()] = not set[opt:lower()]
            local out = {}
            for _, o2 in ipairs(s.options) do if set[o2:lower()] then out[#out + 1] = o2 end end
            changed(row, #out > 0 and table.concat(out, ", ") or s.none)
        end)
        row.chips[#row.chips + 1] = ch
    end
    row.show()
    return row
end
function builders.color(list, s)
    local row = rowShell(list, s)
    nameArea(row)
    pcall(function() row.vbg:SetBrushColor(C.valueBg) end)
    row.swatch = border(C.none)
    local sw = row.valueHB:AddChildToHorizontalBox(sized(row.swatch, 30, 22)); align(sw, 0, 2); pad(sw, 14, 0, 0, 0)
    row.edit = new("EditableText", "Hex")
    applyFont(row.edit, S.edit)
    pcall(function() row.edit:SetText(FText(row.value)) end)
    pcall(function() row.edit:SetColorAndOpacity({ R = 1, G = 1, B = 1, A = 0.85 }) end)
    local es = row.valueHB:AddChildToHorizontalBox(row.edit); grow(es); align(es, 0, 2); pad(es, 14, 0, 14, 0)
    local function rgb(hex)
        -- the hex is sRGB (what the mods use); UMG wants linear
        local function lin(x) x = x / 255; return x <= 0.04045 and x / 12.92 or ((x + 0.055) / 1.055) ^ 2.4 end
        return { R = lin(tonumber(hex:sub(1, 2), 16)), G = lin(tonumber(hex:sub(3, 4), 16)), B = lin(tonumber(hex:sub(5, 6), 16)), A = 1 }
    end
    function row.show()
        if row.value:match("^%x%x%x%x%x%x$") then pcall(function() row.swatch:SetBrushColor(rgb(row.value)) end) end
    end
    row.poll = function()
        local t = nil
        pcall(function() t = row.edit:GetText():ToString() end)
        if t and t ~= row.typed then
            row.typed = t
            local hex = t:gsub("^#", ""):upper()
            if hex:match("^%x%x%x%x%x%x$") then
                if hex ~= row.value then changed(row, hex) end
                pcall(function() row.edit:SetColorAndOpacity({ R = 1, G = 1, B = 1, A = 0.85 }) end)
            else
                pcall(function() row.edit:SetColorAndOpacity(C.bad) end)
            end
        end
        local hv = P.callm(row.edit, "IsHovered") == true
        if hv ~= (row.editHover or false) then row.editHover = hv; rowHover(row, hv) end
    end
    row.show()
    return row
end
---------------------------------------------------------------------------
-- DEBUG tabs. ModMenu's own setting "Debug" (off by default) adds a DEBUG tab
-- to every mod that offers debug actions. A mod publishes them in the shared
-- variable "ModMenu.debug.<folder>" (lines "id<TAB>label<TAB>description");
-- RUN sets "ModMenu.run.<folder>" = "id#stamp" and the mod answers in
-- "ModMenu.reply.<folder>" = "id#stamp<TAB>result". A mod checks twice a second
-- and only sees the newest request, so requests are queued and sent one at a
-- time (four quick presses = four actions).
---------------------------------------------------------------------------
local DBG = { wait = nil, queue = {} }
function P.debugOn()
    for _, m in ipairs(P.ui and P.ui.mods or {}) do
        if m.name == P.selfName then return tostring(m.doc:get("Debug") or ""):lower() == "true" end
    end
    return false
end
-- @dev-begin
-- ModMenu's own DEBUG tab: generic test helpers for any mod (dev builds only;
-- "remove guards" in a public build would be a host cheat in multiplayer)
local function dbgHost()
    local ok, v = pcall(function() return P.pc:HasAuthority() end)
    return ok and v == true
end
local function dbgGet(o, k)
    local ok, v = pcall(function() return o[k] end)
    if ok then return v end
    return nil
end
DBG.tools = {
    { id = "doors", label = "Open all doors", desc = "Host only. Opens every closed, locked, sealed or barricaded door and gate.", run = function()
        if not dbgHost() then return "host only" end
        local closedLike = { [2] = true, [3] = true, [4] = true, [5] = true, [6] = true }   -- SlammedClose, Closed, Locked, Sealed, Barricaded
        local n, tried, seen = 0, 0, {}
        for _, cn in ipairs({ "SBZGate", "SBZDoor" }) do
            for _, g in ipairs(FindAllOf(cn) or {}) do
                local a = P.valid(g) and P.callm(g, "GetAddress")
                local st = a and tonumber(dbgGet(g, "State"))
                if st and closedLike[st] and not seen[a] then
                    seen[a] = true
                    tried = tried + 1
                    local ok, res = pcall(function() return g:SetState(0) end)        -- 0 = open forward
                    if ok and res ~= false then n = n + 1 end
                end
            end
            if tried > 0 then break end
        end
        return string.format("opened %d of %d closed doors", n, tried)
    end },
    { id = "guards", label = "Remove guards", desc = "Host only. Removes every guard and police unit (crew, civilians and hostages stay).", run = function()
        if not dbgHost() then return "host only" end
        local removed, skipped = 0, 0
        for _, ai in ipairs(FindAllOf("SBZAICharacter") or {}) do
            if P.valid(ai) then
                local low = P.classOf(ai):lower()
                if low:find("crew") or low:find("civ") or low:find("hostage") or low:find("player") then
                    skipped = skipped + 1
                else
                    pcall(function() ai.bIsPagerEnabled = false end)
                    if pcall(function() ai:K2_DestroyActor() end) then removed = removed + 1 end
                end
            end
        end
        return string.format("removed %d, kept %d (crew/civilians)", removed, skipped)
    end },
}
-- @dev-end
local function dbgSend(q)
    DBG.n = (DBG.n or 0) + 1
    local stamp = q.id .. "#" .. string.format("%.3f", os.clock()) .. "." .. DBG.n
    pcall(ModRef.SetSharedVariable, ModRef, "ModMenu.run." .. q.mod.name, stamp)
    DBG.wait = { mod = q.mod, stamp = stamp, label = q.label, at = os.clock() }
    P.log("debug: asked %s for %s", q.mod.name, q.id)
    setDescription(q.label .. ": sent to " .. (q.mod.schema.title or q.mod.name) .. "..."
        .. (#DBG.queue > 0 and (" (" .. #DBG.queue .. " more queued)") or ""))
end
local function dbgRequest(m, id, label)
    if not ModRef then setDescription(label .. ": no shared variables (ModRef missing)"); return end
    local q = { mod = m, id = id, label = label }
    if DBG.wait then
        DBG.queue[#DBG.queue + 1] = q
        setDescription(label .. ": queued (" .. #DBG.queue .. " waiting)")
    else
        dbgSend(q)
    end
end
-- a mod's DEBUG tab (nil when Debug is off or the mod offers nothing)
function P.debugSection(mod, settingSpecs)
    if not P.debugOn() then return nil end
    local sec = { name = "Debug", specs = {} }
    for _, sp in ipairs(settingSpecs or {}) do sec.specs[#sec.specs + 1] = sp end   -- debug settings first
    if mod.name == P.selfName then
        for _, t in ipairs(DBG.tools or {}) do
            sec.specs[#sec.specs + 1] = { type = "action", key = "__tool_" .. t.id, label = t.label, desc = t.desc, value = "", run = function()
                local ok, res = pcall(t.run)
                res = ok and tostring(res) or ("error: " .. tostring(res))
                P.log("debug tool %s: %s", t.id, res)
                setDescription(t.label .. ": " .. res)
            end }
        end
    elseif ModRef then
        local ok, list = pcall(ModRef.GetSharedVariable, ModRef, "ModMenu.debug." .. mod.name)
        if ok and type(list) == "string" then
            for line in (list .. "\n"):gmatch("([^\n]*)\n") do
                local id, label, desc = line:match("^([^\t]+)\t([^\t]*)\t?(.*)$")
                if id then
                    sec.specs[#sec.specs + 1] = { type = "action", key = "__act_" .. id, label = label, desc = desc, value = "",
                        run = function() dbgRequest(mod, id, label) end }
                end
            end
        end
    end
    if #sec.specs == 0 then return nil end
    return sec
end
-- while waiting for a mod's answer
function P.debugPoll()
    local w = DBG.wait
    if not w and #DBG.queue > 0 and ModRef then dbgSend(table.remove(DBG.queue, 1)); return end
    if not w or not ModRef then return end
    local ok, r = pcall(ModRef.GetSharedVariable, ModRef, "ModMenu.reply." .. w.mod.name)
    if ok and type(r) == "string" and r:sub(1, #w.stamp + 1) == w.stamp .. "\t" then
        DBG.wait = nil
        P.log("debug: %s answered: %s", w.mod.name, r:sub(#w.stamp + 2))
        setDescription(w.label .. ": " .. r:sub(#w.stamp + 2))
    elseif os.clock() - w.at > 3 then
        DBG.wait = nil
        setDescription(w.label .. ": no answer within 3 s (is the mod running?)")
        DBG.queue = {}                     -- the rest would time out too
    end
end
-- a row with a RUN button
-- Debug actions only make sense in a heist: in the main menu the row is greyed
-- out and RUN does nothing.
function builders.action(list, s)
    local off = P.mapName and P.mapName() == "mainmenu"
    if off and not s.offNote then
        s.offNote = true
        s.desc = ((s.desc or "") ~= "" and (s.desc .. "\n\n") or "") .. "Only in a heist."
    end
    local row = rowShell(list, s)
    nameArea(row)
    local t = optText("RUN")
    if off then
        for i = #row.texts, 1, -1 do if row.texts[i] == row.nameT then table.remove(row.texts, i) end end
        setOpacity(row.nameT, 0.3)
        setOpacity(t, 0.25)
        row.runP = part(row, t, nil, function() setDescription(s.label .. ": only in a heist.") end, nil, true)
    else
        row.texts[#row.texts + 1] = t
        row.runP = part(row, t, nil, function() s.run() end)
    end
    row.off = off
    row.show = function() end
    return row
end
function builders.notice(list, s)
    local row = { s = s, value = "", hoverN = 0, texts = {}, dim = {} }
    local bd = border(C.rowBg, S.namePad + 3, 12, S.namePad + 3, 12)
    local t = text(s.label, S.name, s.color or C.white, true)
    setOpacity(t, 0.9)
    contentIn(bd, t, 0, 2)
    local sl = list:AddChild(bd)
    pad(sl, 0, 0, 0, S.rowGap)
    row.show = function() end
    return row
end
-- readonly: shown, not changeable (schema "readonly", or "mainMenuOnly" in a heist)
function builders.readonly(list, s)
    local row = rowShell(list, s)
    nameArea(row)
    pcall(function() row.vbg:SetBrushColor(C.valueBg) end)
    row.valT = text(row.value, S.value, C.white)
    setOpacity(row.valT, DIM)
    row.texts[#row.texts + 1] = row.valT
    local vs = row.valueHB:AddChildToHorizontalBox(row.valT); grow(vs); align(vs, 2, 2)
    function row.show() setText(row.valT, row.value) end
    return row
end
-- free text: typed like the colour field. ";" and line breaks would break the
-- ini line, so they turn the text red and aren't saved.
function builders.text(list, s)
    local row = rowShell(list, s)
    nameArea(row)
    pcall(function() row.vbg:SetBrushColor(C.valueBg) end)
    row.edit = new("EditableText", "Text")
    applyFont(row.edit, S.edit)
    pcall(function() row.edit:SetText(FText(row.value)) end)
    pcall(function() row.edit:SetColorAndOpacity({ R = 1, G = 1, B = 1, A = 0.85 }) end)
    local es = row.valueHB:AddChildToHorizontalBox(row.edit); grow(es); align(es, 0, 2); pad(es, 14, 0, 14, 0)
    row.typed = row.value
    function row.show() end
    row.poll = function()
        local t = nil
        pcall(function() t = row.edit:GetText():ToString() end)
        if t and t ~= row.typed then
            row.typed = t
            if t:find("[;\r\n]") then
                pcall(function() row.edit:SetColorAndOpacity(C.bad) end)
            else
                pcall(function() row.edit:SetColorAndOpacity({ R = 1, G = 1, B = 1, A = 0.85 }) end)
                local v = t:match("^%s*(.-)%s*$")
                if v ~= row.value then changed(row, v) end
            end
        end
        local hv = P.callm(row.edit, "IsHovered") == true
        if hv ~= (row.editHover or false) then row.editHover = hv; rowHover(row, hv) end
    end
    return row
end

---------------------------------------------------------------------------
-- tab bar (sections), mod list (left), rows
---------------------------------------------------------------------------
local function clearClickables(kind)
    local keep = {}
    for _, b in ipairs(P.ui.buttons) do if b.kind ~= kind then keep[#keep + 1] = b end end
    P.ui.buttons = keep
end
-- a tab's look: selected = green + 1 px line, hovered = dark green + 2 px line
local function paintTab(t, selected, hovered)
    local bg = selected and C.tabSel or (hovered and C.tabHover or C.none)
    pcall(function() t.bg:SetBrushColor(bg) end)
    pcall(function() t.line:SetBrushColor((selected or hovered) and C.white or C.none) end)
    pcall(function() t.lineBox:SetHeightOverride(hovered and not selected and 2 or 1) end)
end
local function groupTitle(list, name)
    local t = text(string.upper(name), S.name, C.white)
    setOpacity(t, 0.5)
    local box = new("Overlay", "GroupTitle")
    local ts = box:AddChildToOverlay(t); align(ts, 0, 3); pad(ts, 1, 0, 0, 0)
    local sz = sized(box, nil, S.groupH)
    local sl = list:AddChild(sz)
    pad(sl, 0, 0, 0, S.rowGap)
    return sz
end
---------------------------------------------------------------------------
-- HUD position preview: a mini copy of the screen (same fractions on both
-- axes, so it has the player's real aspect) on the right, under the
-- description. Every mod with a schema "preview" draws its HUD element there;
-- the selected mod's elements can be dragged, which writes their X/Y settings
-- (on release; live mods move their real HUD right away).
--   "preview": { "x": "PanelX", "y": "PanelY", "align": [1, 0.5],
--                "size": [170, 80], "sizeKey": "IconSize", "label": "HUD" }
-- or a list of those, one per HUD element. Pressing on an element drags it;
-- pressing elsewhere moves the selected one (the last dragged) there.
-- size is in UI units (1920 x 1080 screen); sizeKey = a square size setting.
-- The mouse comes from WidgetLayoutLibrary:GetMousePositionOnViewport (UI
-- units); widget geometry calls return zeros in this UE4SS build, so the
-- frame's place is known because we put it there.
---------------------------------------------------------------------------
local PV = { rect = { 0.625, 0.585, 0.30, 0.30 } }
local function pvLib()
    if not P.valid(PV.wll) then PV.wll = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary") end
    return PV.wll
end
-- the mouse as a fraction of the preview frame (nil if unknown)
local function pvMouse()
    local pc = P.pc
    if not P.valid(pc) then return nil end
    local ok, m, sz, sc = pcall(function()
        local w = pvLib()
        return w:GetMousePositionOnViewport(pc), w:GetViewportSize(pc), w:GetViewportScale(pc)
    end)
    if not ok or not m or not sz or type(sc) ~= "number" or sc <= 0 then return nil end
    local vw, vh = sz.X / sc, sz.Y / sc
    if not vw or vw <= 0 or vh <= 0 then return nil end
    local r = PV.rect
    return (m.X / vw - r[1]) / r[3], (m.Y / vh - r[2]) / r[4], vw, vh
end
-- a mod's preview elements as a list (one object or an array in the schema)
local function pvDefs(mod)
    local d = mod.schema.preview
    if type(d) ~= "table" then return {} end
    if d.x then return { d } end
    local out = {}
    for _, e in ipairs(d) do if type(e) == "table" and e.x and e.y then out[#out + 1] = e end end
    return out
end
local function pvRowOf(key)
    for _, r in ipairs(P.ui and P.ui.rows or {}) do if r.s.key == key then return r end end
    return nil
end
-- a setting's number: the row's live value for the mod on screen (a slider
-- only saves when you leave its row), else the file's
local function pvNum(mod, key, default)
    local cur = P.ui and P.ui.mods[P.ui.modIndex]
    local r = (mod == cur) and pvRowOf(key) or nil
    local v = r and tonumber(r.value) or tonumber(mod.doc:get(key) or "")
    return v or default
end
-- an element's box inside the frame, as fractions of the screen
local function pvBox(mod, d)
    local x, y = pvNum(mod, d.x, 0.5), pvNum(mod, d.y, 0.5)
    local size = d.size or { 60, 60 }
    local w, h = size[1] or 60, size[2] or 60
    if d.sizeKey then local n = pvNum(mod, d.sizeKey, w); w, h = n, n end
    local al = d.align or { 0.5, 0.5 }
    local fw, fh = w / 1920, h / 1080
    local left, top = x - (al[1] or 0.5) * fw, y - (al[2] or 0.5) * fh
    return left, top, fw, fh, x, y
end
local function pvPlace(e)
    local l, t, w, h = pvBox(e.mod, e.def)
    if e.last and e.last[1] == l and e.last[2] == t and e.last[3] == w and e.last[4] == h then return end
    e.last = { l, t, w, h }
    pcall(function()
        e.slot:SetAnchors({ Minimum = { X = l, Y = t }, Maximum = { X = l + w, Y = t + h } })
        e.slot:SetOffsets({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
    end)
    -- the label sits outside the box (boxes are often smaller than their name):
    -- above it, lined up with the edge nearer the frame's middle; below it at the very top
    if e.lslot then
        local right = (l + w / 2) > 0.5
        local below = t < 0.08
        local ax, ay = right and (l + w) or l, below and (t + h) or t
        pcall(function()
            e.lslot:SetAnchors({ Minimum = { X = ax, Y = ay }, Maximum = { X = ax, Y = ay } })
            e.lslot:SetAlignment({ X = right and 1 or 0, Y = below and 0 or 1 })
            e.lslot:SetPosition({ X = 0, Y = below and 2 or -2 })
        end)
    end
end
-- The background: a screenshot of the game's HUD (ModMenu/assets/hud_sample.jpg,
-- 1280 x 720) loaded from disk with KismetRenderingLibrary.ImportFileAsTexture2D.
-- The texture is kept alive by the Image brush that uses it; it's loaded again
-- if the engine has collected it. Missing or failing = the plain dark frame.
local function pvTexture()
    if P.valid(PV.tex) then return PV.tex end
    if PV.texFailed then return nil end
    local path = P.dir .. "\\assets\\hud_sample.jpg"
    local f = io.open(path, "rb")
    if not f then PV.texFailed = true; P.log("preview: no %s", path); return nil end
    f:close()
    local t0 = os.clock()
    local ok, tex = pcall(function()
        local krl = StaticFindObject("/Script/Engine.Default__KismetRenderingLibrary")
        return krl:ImportFileAsTexture2D(P.pc, path)
    end)
    if ok and P.valid(tex) then
        PV.tex = tex
        P.log("preview: background loaded in %.0f ms", (os.clock() - t0) * 1000)
        return tex
    end
    PV.texFailed = true
    P.log("preview: background not loaded (%s)", tostring(tex))
    return nil
end
function P.previewClear()
    local ui = P.ui
    if not ui or not ui.preview then return end
    for _, w in ipairs(ui.preview.widgets) do pcall(function() w:RemoveFromParent() end) end
    clearClickables("preview")
    ui.preview = nil
end
function P.previewBuild(mod, sec)
    P.previewClear()
    local defs = mod and pvDefs(mod) or {}
    local has = false
    for _, sp in ipairs(sec and sec.specs or {}) do
        for _, d in ipairs(defs) do if sp.key == d.x then has = true end end
    end
    if not has then return end
    local d = defs[1]
    local ui = P.ui
    local pv = { mod = mod, widgets = {}, elems = {}, mine = {} }
    ui.preview = pv
    -- the frame: a canvas we place ourselves; elements are anchored inside it
    local fc = new("CanvasPanel", "Preview")
    pcall(function() fc:SetClipping(1) end)          -- ClipToBounds: nothing spills out of the frame
    place(fc, PV.rect)
    pv.widgets[#pv.widgets + 1] = fc
    pcall(function() fc:SetVisibility(VIS.SelfHitTestInvisible) end)
    local function fill(w, l, t, r, bt)
        local sl = fc:AddChildToCanvas(w)
        pcall(function()
            sl:SetAnchors({ Minimum = { X = l, Y = t }, Maximum = { X = r, Y = bt } })
            sl:SetOffsets({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
        end)
        return sl
    end
    local tex = pvTexture()
    if tex then
        local img = new("Image", "PvBg")
        pcall(function() img:SetBrushFromTexture(tex, false) end)
        pcall(function() img:SetColorAndOpacity({ R = 0.55, G = 0.55, B = 0.55, A = 1 }) end)   -- dimmed: the boxes stand out
        pcall(function() img:SetVisibility(VIS.HitTestInvisible) end)
        fill(img, 0, 0, 1, 1)
    else
        fill(border({ R = 0, G = 0, B = 0, A = 0.55 }), 0, 0, 1, 1)
    end
    -- thirds guides, faint
    for _, f in ipairs({ 1 / 3, 2 / 3 }) do
        local v = border({ R = 1, G = 1, B = 1, A = 0.05 })
        local vs = fill(v, f, 0, f, 1); pcall(function() vs:SetOffsets({ Left = 0, Top = 0, Right = 1, Bottom = 0 }) end)
        local h = border({ R = 1, G = 1, B = 1, A = 0.05 })
        local hs = fill(h, 0, f, 1, f); pcall(function() hs:SetOffsets({ Left = 0, Top = 0, Right = 0, Bottom = 1 }) end)
    end
    local ol = outline(C.faint)
    fill(ol.w, 0, 0, 1, 1)
    local cap = text("PREVIEW", 10, C.white)
    setOpacity(cap, 0.6)
    -- on the main canvas: the frame clips everything outside it, and the caption sits above it
    local cs = place(cap, { PV.rect[1], PV.rect[2] }, 0, 1)
    pcall(function() cs:SetPosition({ X = 0, Y = -4 }) end)
    pv.widgets[#pv.widgets + 1] = cap
    -- every mod's elements: the others faded, this mod's bright
    for _, m in ipairs(ui.mods) do
        for _, dm in ipairs(pvDefs(m)) do
            local mine = (m == mod)
            local ov = new("Overlay", "PvElem")
            local bg = border(mine and { R = 1, G = 0.1765, B = 0.0353, A = 0.35 } or { R = 1, G = 1, B = 1, A = 0.08 })
            align(ov:AddChildToOverlay(bg))
            local o2 = outline(mine and C.sliderHot or { R = 1, G = 1, B = 1, A = 0.35 })
            align(ov:AddChildToOverlay(o2.w))
            pcall(function() ov:SetVisibility(VIS.HitTestInvisible) end)
            local e = { w = ov, mod = m, def = dm, mine = mine, bg = bg, ol = o2 }
            e.slot = fc:AddChildToCanvas(ov)
            -- its name, on a dark backing so it reads over the picture
            local lb = border({ R = 0, G = 0, B = 0, A = 0.6 }, 3, 0, 3, 0)
            local lt = text(dm.label or m.schema.title or m.name, 9, mine and C.white or { R = 1, G = 1, B = 1, A = 0.6 })
            contentIn(lb, lt, 2, 2)
            pcall(function() lb:SetVisibility(VIS.HitTestInvisible) end)
            e.lslot = fc:AddChildToCanvas(lb)
            pcall(function() e.lslot:SetAutoSize(true) end)
            pv.widgets[#pv.widgets + 1] = lb
            pvPlace(e)
            pv.elems[#pv.elems + 1] = e
            if mine then pv.mine[#pv.mine + 1] = e end
        end
    end
    pv.sel = pv.mine[1]
    P.previewPaint()
    -- the drag surface: the whole frame
    local cat = catcher()
    pcall(function() cat:SetCursor(10) end)          -- GrabHand
    fill(cat, 0, 0, 1, 1)
    pv.cat = cat
    clickable(cat, { kind = "preview", click = function() end, hover = function(hv)
        ol.set(hv and C.outline or C.faint)
        if hv then
            local sd = pv.sel and pv.sel.def or d
            setDescription(sd.description or (#pv.mine > 1
                and "Drag a highlighted box to move that HUD element (clicking empty space moves the selected one). Other mods' elements are shown faded."
                or "Drag the highlighted box to move this mod's HUD element. The other mods' elements are shown faded for reference."))
        end
    end })
end
-- the selected element (the one a press on empty space moves) is the brightest
function P.previewPaint()
    local pv = P.ui and P.ui.preview
    if not pv then return end
    for _, e in ipairs(pv.mine) do
        local sel = (e == pv.sel) or #pv.mine == 1
        pcall(function() e.bg:SetBrushColor({ R = 1, G = 0.1765, B = 0.0353, A = sel and 0.45 or 0.2 }) end)
        e.ol.set(sel and C.sliderHot or { R = 1, G = 0.1765, B = 0.0353, A = 0.5 })
    end
end
-- per frame while the screen is open: dragging, and following the X/Y rows
function P.previewPoll()
    local pv = P.ui and P.ui.preview
    if not pv or not pv.sel then return end
    local mod = pv.mod
    local pressed = P.callm(pv.cat, "IsPressed") == true
    if pressed then
        local fx, fy = pvMouse()
        if fx then
            if not pv.drag then
                -- grab: the topmost of this mod's elements under the mouse keeps
                -- its offset; a press on empty space moves the selected one there
                local hit = nil
                for i = #pv.mine, 1, -1 do
                    local e = pv.mine[i]
                    local l, t, w, h = pvBox(mod, e.def)
                    if fx >= l and fx <= l + w and fy >= t and fy <= t + h then hit = e; break end
                end
                if hit and hit ~= pv.sel then pv.sel = hit; P.previewPaint() end
                local _, _, _, _, x, y = pvBox(mod, pv.sel.def)
                pv.drag = { ox = hit and (fx - x) or 0, oy = hit and (fy - y) or 0, def = pv.sel.def }
            end
            local d = pv.drag.def
            local rx, ry = pvRowOf(d.x), pvRowOf(d.y)
            local function snap(key, row, v)
                local sp = row and row.s or {}
                local step = sp.step or 0.005
                v = math.max(sp.min or 0, math.min(sp.max or 1, v))
                v = math.floor(v / step + 0.5) * step
                local dec = decimals(step)
                return dec > 0 and string.format("%." .. dec .. "f", v) or tostring(math.floor(v + 0.5))
            end
            local nx, ny = snap(d.x, rx, fx - pv.drag.ox), snap(d.y, ry, fy - pv.drag.oy)
            if nx ~= pv.drag.x or ny ~= pv.drag.y then
                pv.drag.x, pv.drag.y = nx, ny
                mod.doc:set(d.x, nx); mod.doc:set(d.y, ny)        -- in memory; saved on release
                for _, pair in ipairs({ { rx, nx }, { ry, ny } }) do
                    local r = pair[1]
                    if r then r.value = pair[2]; P.try("row show", r.show) end
                end
            end
        end
    elseif pv.drag then
        local dr = pv.drag
        local d = dr.def
        pv.drag = nil
        if dr.x then
            P.log("preview: %s %s = %s, %s = %s", mod.name, d.x, dr.x, d.y, dr.y)
            P.saveSetting(mod, d.x, dr.x)
            P.saveSetting(mod, d.y, dr.y)
            for _, k in ipairs({ d.x, d.y }) do
                local r = pvRowOf(k)
                if r then r.dirty = false; if r.updateReset then r.updateReset() end end
            end
        end
    end
    -- follow the rows (slider drags, RESET, REVERT) and size changes
    for _, e in ipairs(pv.elems) do pvPlace(e) end
end

local function showSection(si)
    local ui = P.ui
    ui.sectionIndex = si
    clearClickables("row")
    pcall(function() ui.list:ClearChildren() end)
    pcall(function() ui.list:ScrollToStart() end)
    ui.rows = {}
    local sec = ui.sections[si]
    -- rows show the current values: a change made earlier on this screen (then
    -- a tab or mod switch, or a page rebuild) must not come back as the old one
    local cur = ui.mods[ui.modIndex]
    for _, sp in ipairs(sec and sec.specs or {}) do
        if sp.key == "__enabled" and cur then sp.value = cur.enabled and "true" or "false"
        elseif cur and sp.type ~= "notice" and sp.type ~= "action" then
            local v = cur.doc:get(sp.key)
            if v ~= nil then sp.value = v end
        end
    end
    local nBefore = #ui.buttons
    local lastGroup = nil
    for _, sp in ipairs(sec and sec.specs or {}) do
        if sp.group and sp.group ~= lastGroup then P.try("group title", groupTitle, ui.list, sp.group) end
        lastGroup = sp.group
        local b = builders[sp.type] or builders.text
        local ok, row = pcall(b, ui.list, sp)
        if ok and row then ui.rows[#ui.rows + 1] = row else P.log("row %s (%s) failed: %s", sp.key, sp.type, tostring(row)) end
    end
    for k = nBefore + 1, #ui.buttons do ui.buttons[k].kind = "row" end
    for k, t in ipairs(ui.tabWidgets or {}) do paintTab(t, k == si, t.hovered) end
    P.try("preview", P.previewBuild, ui.mods[ui.modIndex], sec)
end
local function buildTabs(mod)
    local ui = P.ui
    clearClickables("tab")
    pcall(function() ui.tabBox:ClearChildren() end)
    ui.tabWidgets = {}
    local nBefore = #ui.buttons
    for i, sec in ipairs(ui.sections) do
        -- WBP_UI_Widget_NavBarButton: height 50, min width 150; slanted fill
        -- inset 6 top/bottom; text 12 uppercase, padding 25; a line at the bottom
        local ov = new("Overlay", "TabOv")
        local bg = border(C.none)
        shear(bg, SHEAR)
        local bgs = ov:AddChildToOverlay(bg); align(bgs); pad(bgs, 0, 6, 0, 6)
        local line = border(C.none)
        local lineBox = sized(line, nil, 1)
        local lbs = ov:AddChildToOverlay(lineBox); align(lbs, 0, 3); pad(lbs, -6, 0, 6, 0)
        local t = text(sec.name:upper(), S.tab, C.tabText)
        local ts = ov:AddChildToOverlay(t); align(ts, 2, 2); pad(ts, S.tabPad, 5, S.tabPad, 5)
        local cat = catcher()
        align(ov:AddChildToOverlay(cat))
        local box = new("SizeBox", "TabSize")
        pcall(function() box:SetHeightOverride(S.tabH); box:SetMinDesiredWidth(S.tabMinW); box:SetMaxDesiredWidth(300) end)
        box:SetContent(ov)
        ui.tabBox:AddChildToHorizontalBox(box)
        local tw = { bg = bg, line = line, lineBox = lineBox }
        ui.tabWidgets[i] = tw
        clickable(cat, { click = function() showSection(i) end, hover = function(hv)
            tw.hovered = hv
            paintTab(tw, ui.sectionIndex == i, hv)
        end })
    end
    for k = nBefore + 1, #ui.buttons do ui.buttons[k].kind = "tab" end
end
local function paintMod(m, selected, hovered)
    pcall(function() m.bg:SetBrushColor(selected and C.tabSel or C.rowBg) end)
    m.frame.set(hovered and C.outline or C.faint)
    setOpacity(m.t, (selected or hovered) and 1 or (m.off and DIM * 0.6 or DIM))
end
local function showMod(i)
    local ui = P.ui
    ui.modIndex = i
    local mod = ui.mods[i]
    local hidden = 0
    ui.sections, hidden = sectionsOf(mod or { entries = {}, schema = {} })
    buildTabs(mod)
    showSection(1)
    for k, m in pairs(ui.modWidgets or {}) do paintMod(m, k == i, m.hovered) end
    if ui.menuBtn then paintMod(ui.menuBtn, i == ui.menuIndex, ui.menuBtn.hovered) end
    setDescription(mod and mod.about or "")
    P.setDescTitle(mod)
    if P.refreshStatus then P.refreshStatus() end      -- REVERT belongs to the mod being shown
    P.log("showing %s: %d sections, %d hidden settings", mod and mod.name or "-", #ui.sections, hidden)
end
P.showMod = showMod
P.showSection = function(i) showSection(i) end

---------------------------------------------------------------------------
-- the screen
---------------------------------------------------------------------------
local function image(key, w, h, tint)
    local img = new("Image", "Img")
    local res = asset(key)
    if res then pcall(function() img:SetBrushResourceObject(res) end) end
    if w then pcall(function() img:SetDesiredSizeOverride({ X = w, Y = h }) end) end
    if tint then pcall(function() img:SetColorAndOpacity(tint) end) end
    pcall(function() img:SetVisibility(VIS.HitTestInvisible) end)
    return img, res ~= nil
end
function P.build(pc)
    P.step("S2 build the MODS screen (game recipe)")
    local ui = { buttons = {}, rows = {}, tabs = {} }
    P.ui = ui
    ui.root = P.newObj("/Script/UMG.UserWidget", pc:GetWorld(), "ModMenuRoot")
    ui.tree = P.newObj("/Script/UMG.WidgetTree", ui.root, "ModMenuTree")
    ui.root.WidgetTree = ui.tree
    ui.canvas = P.newObj("/Script/UMG.CanvasPanel", ui.tree, "ModMenuCanvas")
    ui.tree.RootWidget = ui.canvas

    local blk = catcher(); pcall(function() blk:SetCursor(1) end)
    place(blk, { 0, 0, 1, 1 })
    local back = border(C.backdrop)
    pcall(function() back:SetVisibility(VIS.HitTestInvisible) end)
    place(back, { 0, 0, 1, 1 })
    local blur = new("BackgroundBlur", "Blur")
    pcall(function() blur:SetBlurStrength(30) end)
    pcall(function() blur:SetVisibility(VIS.HitTestInvisible) end)
    place(blur, { 0, 0, 1, 1 })

    ui.sink = new("EditableText", "EscSink")
    pcall(function() ui.sink:SetRenderOpacity(0) end)
    place(ui.sink, { 0, 0 })

    -- title (WBP_ScreenTitle): BlackPro 34 uppercase; a 1 px line with a short
    -- green bar on it; "//SELECTION OPEN//" small and green
    local tv = new("VerticalBox", "Title")
    local tt = text("MODS", S.title, C.white, false, "BlackPro")
    pcall(function() tt.Font.LetterSpacing = 1 end)
    tv:AddChildToVerticalBox(tt)
    local uo = new("Overlay", "Underline")
    local slim, okLine = image("line", nil, nil, C.white)
    local ss = uo:AddChildToOverlay(sized(slim, nil, 1)); align(ss, 0, 3)
    local chunky = border(C.titleGreen)
    local cs = uo:AddChildToOverlay(sized(chunky, 46, 2)); align(cs, 1, 3)
    local us = tv:AddChildToVerticalBox(sized(uo, nil, 3)); align(us); pad(us, 0, 1, 0, 3)
    tv:AddChildToVerticalBox(text("//SELECTION OPEN//", S.selOpen, C.titleGreen))
    place(tv, L.title)

    -- tab bar (WBP_UI_NavBar): white end lines, a 50 % black band, both slanted
    local tb = new("Overlay", "TabBar")
    local band = border(C.tabBand)
    shear(band, SHEAR)
    local bs = tb:AddChildToOverlay(band); align(bs); pad(bs, 0, 6, 0, 6)
    local tabRow = new("HorizontalBox", "TabRow")
    local function endLine(l, r)
        local e = border(C.white)
        shear(e, SHEAR)
        local s = tabRow:AddChildToHorizontalBox(sized(e, 2, nil)); align(s); pad(s, l, 6, r, 6)
    end
    endLine(0, 4)
    ui.tabBox = new("HorizontalBox", "Tabs")
    local tbs = tabRow:AddChildToHorizontalBox(ui.tabBox); grow(tbs); align(tbs)
    endLine(4, 0)
    align(tb:AddChildToOverlay(tabRow))
    place(tb, L.tabs)

    -- mod list (left): rows in the game's row style, selected = the tab green
    ui.mods = readMods()
    ui.modList = new("ScrollBox", "ModList")
    local modFrame = new("Overlay", "ModFrame")
    align(modFrame:AddChildToOverlay(outline(C.faint).w))
    local mls = modFrame:AddChildToOverlay(ui.modList); align(mls); pad(mls, 5, 5, 5, 5)
    place(modFrame, L.mods)
    ui.modWidgets = {}
    for i, m in ipairs(ui.mods) do
      if m.name == P.selfName then ui.menuIndex = i else       -- (opened by the button below the list)
        local ov = new("Overlay", "ModOv")
        local bg = border(C.rowBg)
        align(ov:AddChildToOverlay(bg))
        local frame = outline(C.faint)
        align(ov:AddChildToOverlay(frame.w))
        local t = text((m.schema.title or m.name), S.modName, C.white)
        pcall(function() t:SetTextOverflowPolicy(1) end)     -- Ellipsis
        pcall(function() t:SetClipping(1) end)
        local col = new("VerticalBox", "ModCol")
        col:AddChildToVerticalBox(t)
        local tag = text("", 9, C.orange)
        local tgs2 = col:AddChildToVerticalBox(tag); pad(tgs2, 0, 1, 0, 0)
        pcall(function() tag:SetVisibility(VIS.Collapsed) end)
        local ts = ov:AddChildToOverlay(col); align(ts, 1, 2); pad(ts, 12, 0, 8, 0)
        local cat = catcher()
        align(ov:AddChildToOverlay(cat))
        local s = ui.modList:AddChild(sized(ov, nil, S.rowH))
        pad(s, 0, 0, 0, S.rowGap)
        local mw = { bg = bg, frame = frame, t = t, tag = tag, off = (m.enabled == false) }
        ui.modWidgets[i] = mw
        clickable(cat, { click = function() showMod(i) end, kind = "mod",
            hover = function(hv)
                mw.hovered = hv
                paintMod(mw, ui.modIndex == i, hv)
                if hv then setDescription(m.about); P.setDescTitle(m)
                else local cur = ui.mods[ui.modIndex]; P.setDescTitle(cur); setDescription(cur and cur.about) end   -- back to the open mod
            end })
      end
    end
    -- MOD MENU SETTINGS: its own button under the list, styled like the entries
    if ui.menuIndex then
        local mi = ui.menuIndex
        local ov = new("Overlay", "MenuBtn")
        local bg = border(C.rowBg)
        align(ov:AddChildToOverlay(bg))
        local frame = outline(C.faint)
        align(ov:AddChildToOverlay(frame.w))
        local t = text("MOD MENU SETTINGS", 13, C.white)
        pcall(function() t.Font.LetterSpacing = 60 end)
        local ts = ov:AddChildToOverlay(t); align(ts, 2, 2)
        local cat = catcher()
        align(ov:AddChildToOverlay(cat))
        place(ov, L.menuBtn)
        local mw = { bg = bg, frame = frame, t = t }
        ui.menuBtn = mw
        clickable(cat, { click = function() showMod(mi) end, kind = "mod",
            hover = function(hv)
                mw.hovered = hv
                paintMod(mw, ui.modIndex == mi, hv)
                if hv then setDescription(ui.mods[mi].about); P.setDescTitle(ui.mods[mi])
                else local cur = ui.mods[ui.modIndex]; P.setDescTitle(cur); setDescription(cur and cur.about) end
            end })
        paintMod(mw, false, false)
    end

    ui.list = new("ScrollBox", "List")
    place(ui.list, L.rows)
    for _, sb in ipairs({ ui.list, ui.modList }) do
        pcall(function() sb:SetAlwaysShowScrollbar(true) end)
        pcall(function() sb:SetScrollbarThickness({ X = 6, Y = 6 }) end)
        pcall(function() sb:SetScrollbarPadding({ Left = 8, Top = 2, Right = 2, Bottom = 2 }) end)
    end
    ui.desc = text("", S.desc, C.white, true)
    setOpacity(ui.desc, 0.9)
    place(ui.desc, L.desc)
    -- the full mod name (list entries cut long names off), sub-header style
    ui.descTitle = text(" ", S.name, C.white)
    setOpacity(ui.descTitle, 0.5)
    place(ui.descTitle, L.descTitle)

    -- hint bar (game recipe): orange strip, black box with a slight slant on
    -- the right, hints [keycap] LABEL. The bar sizes to its hints like the game's.
    local HB = { y = 0.9319, h = 56, shear = SHEAR, left = 110, hidden = 60, cap = 30, gap = 8, between = 26, right = 28 }
    local hb = new("Overlay", "Hint")
    local hbg = border(C.hintBg)
    shear(hbg, HB.shear)
    align(hb:AddChildToOverlay(hbg))
    local hrow = new("HorizontalBox", "HintRow")
    local hrs = hb:AddChildToOverlay(hrow); align(hrs, 0, 2); pad(hrs, HB.left + HB.hidden - 6, 0, HB.right - 6, 0)
    local function hint(key, label, onClick)
        local item = new("Overlay", "HintItem")
        local hot = border(C.none)                      -- hover: faint fill + white outline
        align(item:AddChildToOverlay(hot))
        local ol = outline(C.none)
        align(item:AddChildToOverlay(ol.w))
        local row = new("HorizontalBox", "HintItemRow")
        if key then
            local cap = new("Overlay", "Keycap")
            local capImg, okCap = image("keycap", nil, nil, C.white)
            if okCap then pcall(function() capImg.Brush.DrawAs = 1; capImg.Brush.Margin = { Left = 0.01, Top = 0.01, Right = 0.01, Bottom = 0.01 } end)
            else pcall(function() capImg:SetColorAndOpacity(C.white) end) end
            align(cap:AddChildToOverlay(capImg))
            local sb = new("ScaleBox", "KeyScale")
            pcall(function() sb:SetStretch(2); sb:SetStretchDirection(1) end)   -- ScaleToFit, down only
            sb:SetContent(text(key, S.hintKey, C.black))
            local ct = cap:AddChildToOverlay(sb); align(ct, 2, 2); pad(ct, 4, 0, 4, 0)
            local capBox = new("SizeBox", "CapSize")
            pcall(function() capBox:SetWidthOverride(HB.cap); capBox:SetHeightOverride(HB.cap) end)
            capBox:SetContent(cap)
            align(row:AddChildToHorizontalBox(capBox), 0, 2)
        end
        local lt = text(label, S.hint, C.white)
        setOpacity(lt, 0.8)
        local ls = row:AddChildToHorizontalBox(lt); align(ls, 0, 2); pad(ls, key and HB.gap or 0, 0, 0, 0)
        local rs = item:AddChildToOverlay(row); align(rs, 0, 2); pad(rs, 6, 6, 6, 6)
        local c = catcher()
        align(item:AddChildToOverlay(c))
        clickable(c, { kind = "fixed", click = onClick, hover = function(hv)
            setOpacity(lt, hv and 1 or 0.8)
            pcall(function() hot:SetBrushColor(hv and C.btnHover or C.none) end)
            ol.set(hv and C.white or C.none)
        end })
        return item
    end
    local backItem = hint("Esc", "BACK", function() P.close("BACK") end)
    align(hrow:AddChildToHorizontalBox(backItem), 0, 2)
    local rv = hint(nil, "REVERT CHANGES", function()
        local mod = curMod()
        if not mod then return end
        local doc = INI.parse(mod.openText)
        mod.doc, mod.entries = doc, doc:entries()
        mod.saveAt = os.clock()
        P.log("reverted %s to the file as it was when the screen opened", mod.name)
        P.flushSaves(true)
        local si = ui.sectionIndex
        P.showMod(ui.modIndex)
        if si and ui.sections[si] then P.showSection(si) end
        P.refreshStatus()
    end)
    local rvs = hrow:AddChildToHorizontalBox(rv); align(rvs, 0, 2); pad(rvs, HB.between - 12, 0, 0, 0)
    pcall(function() rv:SetVisibility(VIS.Collapsed) end)
    ui.revert = rv
    local hbSlot = place(sized(hb, nil, HB.h), { 0, HB.y }, 0, 0.5)
    pcall(function() hbSlot:SetOffsets({ Left = -HB.hidden, Top = 0, Right = 0, Bottom = 0 }) end)
    -- the orange strip at the screen edge, on top of the bar
    place(sized(border(C.orange), 4.5, HB.h), { 0, HB.y }, 0, 0.5)

    showMod(1)
    P.refreshStatus()
    P.try("root vis", function() ui.root:SetVisibility(VIS.SelfHitTestInvisible) end)
    P.try("canvas vis", function() ui.canvas:SetVisibility(VIS.SelfHitTestInvisible) end)
    ui.root:AddToViewport(1000)
    P.try("focus the Esc sink", function() ui.sink:SetKeyboardFocus() end)
    P.log("MODS screen built: %d mods (font %s, line texture %s, keycap %s)", #ui.mods,
        findGameFont() and "game" or "default", okLine and "ok" or "missing", okCap and "ok" or "missing")
end

function P.pollButtons()
    if not P.ui then return end
    for _, b in ipairs(P.ui.buttons) do
        local pr = P.callm(b.btn, "IsPressed") == true
        local hv = P.callm(b.btn, "IsHovered") == true
        if hv ~= b.hovered then
            b.hovered = hv
            if b.hover then P.try("hover", b.hover, hv) end
        end
        if pr and b.drag then P.try("drag", b.drag) end
        if pr ~= b.pressed then
            local was = b.pressed
            b.pressed = pr
            if was and not pr and hv then
                P.try("click", b.click)
                if not P.ui then return end
                break       -- the click may have rebuilt the lists
            end
        end
    end
    if not P.ui then return end
    P.flushSaves(false)
    for _, r in ipairs(P.ui.rows) do if r.poll then P.try("row poll", r.poll) end end
    if P.previewPoll then P.try("preview poll", P.previewPoll) end
    if P.debugPoll then P.try("debug poll", P.debugPoll) end
    if os.clock() - (P.ui.sinkAt or 0) > 0.5 then
        P.ui.sinkAt = os.clock()
        local editing = false
        for _, r in ipairs(P.ui.rows) do if r.edit and P.callm(r.edit, "HasKeyboardFocus") == true then editing = true end end
        if not editing and P.callm(P.ui.sink, "HasKeyboardFocus") ~= true then
            P.try("refocus sink", function() P.ui.sink:SetKeyboardFocus() end)
        end
    end
end

---------------------------------------------------------------------------
-- open / close, Esc, level scans
---------------------------------------------------------------------------
function P.gameMenuOwners()
    local out = {}
    for _, e in pairs(P.injected) do
        local owner = e.ov and P.valid(e.ov) and P.ownerOf(P.callm(e.ov, "GetParent"))
        if owner and P.valid(owner) then out[#out + 1] = owner end
    end
    return out
end
function P.openMenu(pc)
    P.log("open MODS screen (cursor shown: %s, paused: %s)", tostring(pc.bShowMouseCursor), P.paused(pc))
    P.pausedAt = os.clock()
    if P.ui and P.valid(P.ui.root) then P.try("remove old", function() P.ui.root:RemoveFromParent() end) end
    P.ui = nil
    P.build(pc)
    P.hidden = {}
    for _, o in ipairs(P.gameMenuOwners()) do
        local v = P.callm(o, "GetVisibility")
        P.hidden[#P.hidden + 1] = { o = o, v = v }
        P.try("hide game menu", function() o:SetVisibility(VIS.Collapsed) end)
    end
    P.setGameAndUI(pc)
    P.open = true
end
function P.close(why)
    P.log("close MODS screen (%s); paused = %s", why, P.valid(P.pc) and P.paused(P.pc) or "?")
    P.try("final save", P.flushSaves, true)
    if P.ui and P.valid(P.ui.root) then P.try("remove", function() P.ui.root:RemoveFromParent() end) end
    P.ui = nil
    for _, h in ipairs(P.hidden or {}) do
        if P.valid(h.o) then P.try("show game menu", function() h.o:SetVisibility(type(h.v) == "number" and h.v or VIS.SelfHitTestInvisible) end) end
    end
    P.hidden = {}
    if P.valid(P.pc) then P.restoreInput(P.pc, why) end
    P.open = false
end

P.escFlag = false
do
    local ok, err = pcall(RegisterKeyBind, Key.ESCAPE, function() P.escFlag = true end)
    P.log("RegisterKeyBind(ESCAPE): %s", ok and "ok" or tostring(err))
end
function P.checkEsc(pc)
    if not P.escFlag then return end
    P.escFlag = false
    if P.open then P.close("Esc") end
end
function P.mapName()
    local w = P.valid(P.pc) and P.callm(P.pc, "GetWorld")
    return w and P.nameOf(w):lower() or "?"
end
local function haveEntry(mi)
    for _, e in pairs(P.injected) do if e.m == P.MENUS[mi] and P.valid(e.ov) then return true end end
    return false
end
-- In a heist the pause-menu entry is added when the cursor appears (= a menu
-- opened), with two retries in case the menu isn't built on that frame. No
-- timed scans during play: each costs ~25 ms (a visible hitch).
-- In the main menu the construct hook adds the entry; timed scans only if not.
function P.levelScans(pc)
    local now = os.clock()
    local cur = pc.bShowMouseCursor == true
    local inMain = P.mapName() == "mainmenu"
    if cur and not P.lastCursor then
        P.labelFastUntil = now + 1.0          -- a menu opened: the game may reset our label
        if not P.open and not inMain and not haveEntry(2) then
            P.try("menu-open scan", P.inject, pc, "menu opened", 2)
            P.menuRetry = { now + 0.25, now + 0.75 }
        end
    end
    P.lastCursor = cur
    if P.menuRetry and now >= P.menuRetry[1] then
        table.remove(P.menuRetry, 1)
        if cur and not P.open and not inMain and not haveEntry(2) then
            P.try("menu-open retry", P.inject, pc, "menu opened, retry", 2)
        end
        if #P.menuRetry == 0 then P.menuRetry = nil end
    end
    if not P.levelScanAt or now < P.levelScanAt[1] then return end
    table.remove(P.levelScanAt, 1)
    if not inMain or haveEntry(1) then P.levelScanAt = nil; return end
    P.try("level scan", P.inject, pc, "level-load scan", 1)
    if #P.levelScanAt == 0 then P.levelScanAt = nil end
end

do
    P.loadText, P.loadEnabled = {}, {}
    local ok, dirs = pcall(IterateGameDirectories)
    local root = ok and dirs and dirs.Game and dirs.Game.Binaries and dirs.Game.Binaries.Win64
        and dirs.Game.Binaries.Win64.ue4ss and dirs.Game.Binaries.Win64.ue4ss.Mods
    local modsDir = P.dir:gsub("[/\\][^/\\]+$", "")
    for name, d in pairs(root or {}) do
        if type(d) == "table" and not tostring(name):find("^__") then
            local f = io.open(modsDir .. "\\" .. name .. "\\settings.ini", "rb")
            if f then P.loadText[name] = f:read("a"); f:close() end
            P.loadEnabled[tostring(name)] = (P.modState(tostring(name)))      -- on/off when the mods started
        end
    end
    local n = 0
    for _ in pairs(P.loadText) do n = n + 1 end
    P.log("snapshot of %d settings files taken at load", n)
end
P.log("screen code loaded (ini %s, json %s)", INI and "ok" or "missing", JSON and "ok" or "missing")

_G.MMP = P   -- tests/modmenusim.py drives the screen through this (each mod has its own Lua state)
