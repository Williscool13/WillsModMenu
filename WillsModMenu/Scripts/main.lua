-- ModMenu: an in-game settings menu for UE4SS mods (PAYDAY 3).
--
-- Adds a MODS entry to the game's main menu and pause menu (and F10 as a
-- fallback) that opens a screen styled like the game's Settings. It edits each
-- mod's own settings.ini (optionally described by settings.schema.json), so
-- mods need no code dependency on this one.
--
-- Rules learned the hard way (UE4SS 3.0.1 in PAYDAY 3):
--   * never call delegates (OnClicked etc.): clicks are polled (IsPressed/IsHovered)
--   * GetFName/GetClass on a null object crashes outside pcall's reach: P.valid first
--   * compare UObjects by GetAddress, never by Lua wrapper
--   * never inject into class templates; never move the game's own buttons
--   * hooks are unregistered on reload (hooks.txt)
-- All state lives in one table (Lua's 200-locals limit).

local P = {
    TAG = "[WillsModMenu] ",
    KEY = "F10",
    open = false,
    ui = nil,            -- the MODS screen while it's open (screen.lua)
    pc = nil, pcScan = -1, world = nil,
    changedCursor = false,
    perf = { t0 = os.clock(), n = 0, sum = 0, worst = 0 },
    dir = nil,           -- this mod's folder
    VERBOSE = false,
    nameN = 0,
}
local VIS = { Visible = 0, Collapsed = 1, Hidden = 2, HitTestInvisible = 3, SelfHitTestInvisible = 4 }

function P.log(fmt, ...) print(P.TAG .. string.format(fmt, ...) .. "\n") end
P.VERBOSE = true   -- @dev
-- step lines name the last engine call before a crash (dev builds only)
function P.step(fmt, ...) if P.VERBOSE then P.log("step: " .. fmt, ...) end end
local function _call(o, m, ...) return o[m](o, ...) end
local function _isValid(o) return o:IsValid() end
function P.valid(o)
    if o == nil then return false end
    local ok, v = pcall(_isValid, o)
    return ok and v == true
end
function P.callm(o, m, ...)
    local ok, v = pcall(_call, o, m, ...)
    if ok then return v end
    return nil
end
function P.try(what, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then P.log("FAILED %s: %s", what, tostring(err)) end
    return ok, err
end

-- This mod's folder (reload flag, hooks file, bundled schemas)
do
    local src = (debug and debug.getinfo and debug.getinfo(1, "S").source) or ""
    P.dir = src:gsub("^@", ""):gsub("[/\\]Scripts[/\\][^/\\]*$", "")
end
P.FLAG = P.dir .. "\\cursor_changed.flag"
P.selfName = P.dir:match("([^/\\]+)$") or "WillsModMenu"   -- this mod's folder (it lists itself differently)

---------------------------------------------------------------------------
-- Player controller (cached; the search only runs while none is known)
---------------------------------------------------------------------------
-- After a level change the previous level's controller stays valid until the
-- engine's garbage collection (~1 min) and still reports its old state (e.g.
-- the main menu's cursor). So the controller in use at a level change is
-- marked dead and skipped. If no other one turns up for 5 s (a game that keeps
-- its controller across levels), the dead list is cleared.
P.deadPC = {}
function P.localPC()
    if P.valid(P.pc) then return P.pc end
    if P.pc ~= nil then P.log("player controller lost") end
    P.pc = nil
    local now = os.clock()
    if now - P.pcScan < 1.0 then return nil end
    P.pcScan = now
    for a, o in pairs(P.deadPC) do if not P.valid(o) then P.deadPC[a] = nil end end
    for _, c in ipairs(FindAllOf("PlayerController") or {}) do
        if P.valid(c) and not P.deadPC[P.callm(c, "GetAddress") or 0] and P.callm(c, "IsLocalController") == true then
            P.pc = c
            local w = P.callm(c, "GetWorld")
            P.pcWorld = w and P.callm(w, "GetAddress") or 0   -- the world it belongs to
            P.lastCursor = nil            -- read this controller's cursor state fresh
            P.noPCSince = nil
            break
        end
    end
    if not P.pc and next(P.deadPC) then
        P.noPCSince = P.noPCSince or now
        if now - P.noPCSince > 5 then P.log("no new player controller: forgetting the old ones"); P.deadPC = {}; P.noPCSince = nil end
    end
    return P.pc
end

---------------------------------------------------------------------------
-- Cursor / input mode. Changed only if the cursor was hidden when we opened.
---------------------------------------------------------------------------
P.WBL_PATH = "/Script/UMG.Default__WidgetBlueprintLibrary"
function P.wbl()
    if not P.valid(P._wbl) then P._wbl = StaticFindObject(P.WBL_PATH) end   -- always loaded: cheap
    return P._wbl
end
function P.setGameAndUI(pc)
    P.step("4a cursor shown? %s", tostring(pc.bShowMouseCursor))
    if pc.bShowMouseCursor == true then P.changedCursor = false; return end
    P.step("4b set bShowMouseCursor = true")
    P.try("cursor on", function() pc.bShowMouseCursor = true end)
    P.step("4c WidgetBlueprintLibrary.SetInputMode_GameAndUIEx(pc, nil, 0, false)")
    P.try("SetInputMode_GameAndUIEx", function() P.wbl():SetInputMode_GameAndUIEx(pc, nil, 0, false, false) end)
    P.changedCursor = true
    local f = io.open(P.FLAG, "w"); if f then f:write("1"); f:close() end
    P.step("4d input mode set")
end
function P.restoreInput(pc, why)
    if not P.changedCursor then return end
    P.step("4e restore (%s): SetInputMode_GameOnly + cursor off", why)
    P.try("SetInputMode_GameOnly", function() P.wbl():SetInputMode_GameOnly(pc) end)
    P.try("cursor off", function() pc.bShowMouseCursor = false end)
    P.changedCursor = false
    os.remove(P.FLAG)
    P.step("4f restored")
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
-- Object names are unique across reloads: Ctrl+R restarts the counter, and a
-- name still used by the previous load's (removed, not yet collected) widgets
-- makes the engine reuse that object, which the next garbage collection then
-- takes away from under the open screen (its buttons stop responding).
P.loadTag = string.format("%x", math.floor(os.clock() * 1000) % 0xFFFFFF)
function P.newObj(classPath, outer, base)
    P.nameN = P.nameN + 1
    return StaticConstructObject(StaticFindObject(classPath), outer, FName(base .. "_" .. P.loadTag .. "_" .. P.nameN))
end
function P.removeStale()
    -- After a Ctrl+R the old panel stays on screen with no Lua behind it.
    local n = 0
    for _, w in ipairs(FindAllOf("UserWidget") or {}) do
        local nm = P.valid(w) and P.callm(w, "GetFName")
        nm = nm and P.callm(nm, "ToString") or ""
        if nm:find("^ModMenuRoot") then
            P.try("remove stale", function() w:RemoveFromParent() end); n = n + 1
        end
    end
    P.log("removed %d stale panel(s)", n)
end

function P.paused(pc)
    if not P.valid(P._gps) then P._gps = StaticFindObject("/Script/Engine.Default__GameplayStatics") end
    return tostring(P.callm(P._gps, "IsGamePaused", pc))
end
-- Only on valid objects: GetFName on a null object crashes UE4SS (pcall can't catch it)
function P.nameOf(o)
    if not P.valid(o) then return "none" end
    local n = P.callm(o, "GetFName")
    return n and P.callm(n, "ToString") or "?"
end
function P.classOf(o)
    if not P.valid(o) then return "none" end
    local c = P.callm(o, "GetClass")
    return c and P.nameOf(c) or "?"
end
---------------------------------------------------------------------------
-- Main loop. Closed and no menu up: a key flag, a world check 4x a second.
---------------------------------------------------------------------------
P.fkey = nil
P.keyFlag = false
if type(RegisterKeyBind) == "function" and Key and Key.F10 then
    local ok, err = pcall(RegisterKeyBind, Key.F10, function() P.keyFlag = true end)
    P.hookOK = ok
    P.log("RegisterKeyBind(F10): %s", ok and "ok" or tostring(err))
else
    P.log("RegisterKeyBind not available (type %s, Key.F10 %s)", type(RegisterKeyBind), tostring(Key and Key.F10))
end
function P.frame()
    local c0 = os.clock()
    local pc = P.localPC()
    if pc then
        local w = P.world
        if c0 >= (P.worldAt or 0) then
            P.worldAt = c0 + 0.25
            w = P.callm(pc, "GetWorld")
            w = w and P.callm(w, "GetAddress") or 0
        end
        if w ~= P.world then
            if P.world ~= nil then
                P.log("level changed: screen dropped")
                if P.flushSaves then P.try("save before level change", P.flushSaves, true) end
                P.ui, P.open, P.changedCursor = nil, false, false
                P.hidden = {}
                for _, e in pairs(P.injected) do
                    if P.valid(e.ov) then P.try("remove old entry", function() e.ov:RemoveFromParent() end) end
                end
                P.injected = {}
                P.autoAt = nil              -- the construct hook / level scans handle new levels
                local t0 = os.clock()
                P.levelScanAt = { t0 + 3, t0 + 8, t0 + 15 }
                -- a controller now reporting another world than the one it had
                -- when we picked it up belongs to an old level: drop it for good
                if P.pcWorld ~= w then
                    local a = P.callm(pc, "GetAddress")
                    if a then P.deadPC[a] = pc end
                    P.pc, P.pcScan, P.lastCursor = nil, -1, nil
                    P.world = w
                    return
                end
            end
            P.world = w
        end
        local polled = false
        if not P.hookOK then
            P.fkey = P.fkey or { KeyName = FName(P.KEY) }
            local ok, down = pcall(_call, pc, "WasInputKeyJustPressed", P.fkey)
            polled = ok and down == true
        end
        local hooked = P.keyFlag
        P.keyFlag = false
        if polled or hooked then
            P.lastToggle = os.clock()
            P.log("F10 pressed: seen by %s%s (menu open=%s, cursor shown=%s, paused=%s)",
                polled and "polling " or "", hooked and "key hook" or "", tostring(P.open), tostring(pc.bShowMouseCursor), P.paused(pc))
            if P.open then P.close("F10") else P.try("open", P.openMenu, pc) end
        end
        P.tryHookClasses()
        P.reportHooks(pc)
        -- the MODS entries only matter while a menu (= the cursor) is up
        if pc.bShowMouseCursor == true or P.open then P.checkModsClick(pc) end
        P.startupScan(pc)
        if P.checkEsc then P.checkEsc(pc) end
        if P.levelScans then P.levelScans(pc) end
        if P.open and P.ui then P.pollButtons() end
    end
    if not P.VERBOSE then return end
    local dt = os.clock() - c0
    local pf = P.perf
    pf.n, pf.sum = pf.n + 1, pf.sum + dt
    if dt > pf.worst then pf.worst = dt end
    if c0 - pf.t0 >= 30 then
        P.log("perf: %d frames, avg %.3f ms, worst %.1f ms (menu %s)", pf.n, pf.sum / pf.n * 1000, pf.worst * 1000, P.open and "open" or "closed")
        pf.t0, pf.n, pf.sum, pf.worst = c0, 0, 0, 0
    end
end

P.MENUS = {
    { what = "main menu",  cls = "WBP_MenuRoot_SecondaryTextButton_C", btn = "SettingsButton",  list = "TitleButtons_VB", label = "MODS" },
    { what = "pause menu", cls = "WBP_UI_TextButton_C",                btn = "Button_Settings", list = "Buttons_VB",      label = "Mods" },
}
P.injected = {}          -- list address -> { w = widget, addr = widget address, what }
-- The MODS entry in the game's own menus (main menu TitleButtons_VB, pause
-- menu Buttons_VB). Moving the game's buttons or hooking their native class
-- caused exit crashes, so:
--   * our entry goes at the END of the list; no hooks on the game's button class
--   * it's an Overlay: a transparent UButton (catches the mouse; clicks polled)
--     under a copy of the game's button, which is HitTestInvisible and only
--     draws. On hover the copy gets real focus, so it highlights like its
--     neighbours.
P.HOOKS_FILE = P.dir .. "\\hooks.txt"
do
    local f = io.open(P.HOOKS_FILE, "rb")
    if f then
        for ln in f:lines() do
            local fn, pre, post = ln:match("^(.-)|(%-?%d+)|(%-?%d+)")
            if fn and type(UnregisterHook) == "function" then
                local ok, err = pcall(UnregisterHook, fn, tonumber(pre), tonumber(post))
                P.log("unregistered old hook %s (%s, %s): %s", fn, pre, post, ok and "ok" or tostring(err))
            end
        end
        f:close()
        os.remove(P.HOOKS_FILE)
    end
end
P.OVERLAY_PREFIX = "ModMenuEntry"
function P.readLabel(e)
    local t = nil
    pcall(function() t = e.w.Title_T:GetText():ToString() end)
    if not t then pcall(function() t = e.w.Text_DisplayText:GetText():ToString() end) end
    return t
end
function P.setLabel(e)
    local w, m = e.w, e.m
    if m.cls == "WBP_UI_TextButton_C" then pcall(function() w:SetButtonText(FText(m.label)) end) end
    pcall(function() w.Title_T:SetText(FText(m.label)) end)
    pcall(function() w.Text_DisplayText:SetText(FText(m.label)) end)
end
-- find our entry already in a list (after a level change or a reload)
function P.findEntry(list, m)
    local n = P.callm(list, "GetChildrenCount") or 0
    for i = 0, n - 1 do
        local c = P.callm(list, "GetChildAt", i)
        if P.valid(c) and P.nameOf(c):find("^" .. P.OVERLAY_PREFIX) then
            local catcher = P.callm(c, "GetChildAt", 0)
            local w = P.callm(c, "GetChildAt", 1)
            if P.valid(catcher) and P.valid(w) then return { ov = c, catcher = catcher, w = w, m = m } end
        end
    end
    return nil
end
function P.buildEntry(pc, list, anchor, m)
    local tree = P.callm(list, "GetOuter")
    P.step("11b %s: overlay + click catcher + game button", m.what)
    local ov = P.newObj("/Script/UMG.Overlay", tree, P.OVERLAY_PREFIX)
    local catcher = P.newObj("/Script/UMG.Button", tree, P.OVERLAY_PREFIX .. "Catcher")
    pcall(function() catcher:SetCursor(9) end)            -- hand cursor, like the game's buttons
    P.try("catcher transparent", function() catcher:SetRenderOpacity(0) end)
    local cls = P.callm(anchor, "GetClass")
    local w = nil
    P.try("Create", function() w = P.wbl():Create(pc, cls, pc) end)
    if not P.valid(w) then
        P.log("%s: Create(pc, cls, pc) returned nothing (pc %s, local %s, world %s); trying without an owning player",
            m.what, P.nameOf(pc), tostring(P.callm(pc, "IsLocalController")), P.nameOf(P.callm(pc, "GetWorld")))
        P.try("Create (no owner)", function() w = P.wbl():Create(list, cls, nil) end)
    end
    if not P.valid(w) then P.log("%s: Create returned nothing", m.what); return nil end
    local s1 = P.callm(ov, "AddChildToOverlay", catcher)
    local s2 = P.callm(ov, "AddChildToOverlay", w)
    for _, sl in ipairs({ s1, s2 }) do
        P.try("fill", function() sl:SetHorizontalAlignment(0); sl:SetVerticalAlignment(0) end)   -- 0 = Fill
    end
    P.try("game button draws only", function() w:SetVisibility(3) end)   -- HitTestInvisible
    P.try("catcher visible", function() catcher:SetVisibility(0) end)
    local pad = nil
    pcall(function() pad = anchor.Slot.Padding end)
    P.step("11d %s: append to %s (game buttons not moved)", m.what, m.list)
    local slot = P.callm(list, "AddChildToVerticalBox", ov)
    if slot and pad then P.try("padding", function() slot:SetPadding(pad) end) end
    local e = { ov = ov, catcher = catcher, w = w, m = m, labelUntil = os.clock() + 1.5 }
    P.setLabel(e)
    P.log("%s: entry added at index %s", m.what, tostring(P.callm(list, "GetChildIndex", ov)))
    return e
end
-- Only live menus (never class templates). Entries come from a construct hook
-- on the main menu class; scans are the fallback.
function P.isTemplate(owner)
    if not P.valid(owner) then return true end
    return P.classOf(owner):find("GeneratedClass") ~= nil
end
function P.handleList(pc, m, anchor, list, how)
    local owner = P.ownerOf(list)
    if P.isTemplate(owner) then
        local old = P.findEntry(list, m)
        if old then
            P.log("%s: removing our entry from the class template %s", m.what, P.nameOf(owner))
            P.try("remove from template", function() old.ov:RemoveFromParent() end)
        end
        return false
    end
    local la = P.callm(list, "GetAddress")
    local have = P.injected[la]
    if not (have and P.valid(have.ov)) then
        local old = P.findEntry(list, m)
        have = nil
        if old then
            local own = P.callm(old.w, "GetOwningPlayer")
            if own and P.callm(own, "GetAddress") == P.callm(pc, "GetAddress") then
                have = old
                P.log("%s: adopted our entry already in %s", m.what, P.nameOf(owner))
            else
                P.try("remove stale entry", function() old.ov:RemoveFromParent() end)
            end
        end
    end
    if not have then
        have = P.buildEntry(pc, list, anchor, m)
        if have then P.log("%s: entry added to %s (via %s)", m.what, P.nameOf(owner), how) end
    end
    if have then
        have.what = m.what .. " in " .. P.nameOf(owner)
        P.injected[la] = have
    end
    return have ~= nil
end
-- FindAllOf costs ~25 ms per class here, so callers name the one menu that can
-- exist on the current map (only = 1 main menu, 2 pause menu; nil = both).
function P.inject(pc, how, only)
    how = how or "scan"
    for mi, m in ipairs(P.MENUS) do
      if only == nil or only == mi then
        local live = 0
        for _, b in ipairs(FindAllOf(m.cls) or {}) do
            local par = (P.valid(b) and P.nameOf(b) == m.btn) and P.callm(b, "GetParent") or nil
            if par and P.nameOf(par) == m.list then
                if P.handleList(pc, m, b, par, how) then live = live + 1 end
            end
        end
        P.log("%s: %d live list(s) (%s)", m.what, live, how)
      end
    end
end
-- walk one widget's tree to a child with this name (no global search)
function P.findInTree(root, name)
    local found, n = nil, 0
    local function walk(node, depth)
        if found or depth > 30 or n > 3000 or not P.valid(node) then return end
        n = n + 1
        if P.nameOf(node) == name then found = node; return end
        local tree = nil
        pcall(function() tree = node.WidgetTree end)
        if tree and P.valid(tree) then
            local r = nil
            pcall(function() r = tree.RootWidget end)
            if r then walk(r, depth + 1) end
        end
        local cnt = P.callm(node, "GetChildrenCount")
        if type(cnt) == "number" then
            for i = 0, cnt - 1 do walk(P.callm(node, "GetChildAt", i), depth + 1) end
        else
            local c = P.callm(node, "GetContent")
            if c then walk(c, depth + 1) end
        end
    end
    walk(root, 0)
    return found
end
function P.injectOwner(pc, m, owner)
    if P.isTemplate(owner) then return end
    local list = P.findInTree(owner, m.list)
    local anchor = list and P.findInTree(list, m.btn)
    if list and anchor then
        P.handleList(pc, m, anchor, list, "construct hook")
    else
        P.log("%s: hook fired on %s but its %s is not there yet", m.what, P.nameOf(owner), m.list)
    end
end
P.HOOK_CLASSES = {
    { path = "/Game/DLCs/00080-DLC0004/UI/Menus/MenuRoot/WBP_MenuRoot.WBP_MenuRoot_C", menu = 1 },
}
P.HOOK_FNS = { "PreConstruct", "OnInitialized" }
P.hookFired, P.pendingOwners = {}, {}
-- (the pause menu, WBP_UI_ActionPhaseMenu_More_C, has no usable construct
-- event: it's handled by the level scans and the cursor trigger in screen.lua)
function P.tryHookClasses()
    if P.allHooked then return end
    local now = os.clock()
    if now < (P.hookTry or 0) then return end
    P.hookTries = (P.hookTries or 0) + 1
    P.hookTry = now + (P.hookTries < 4 and 5 or 60)    -- a failed RegisterHook costs a few ms
    local missing = 0
    for _, hc in ipairs(P.HOOK_CLASSES) do
        for _, fn in ipairs(P.HOOK_FNS) do
            local key = hc.path .. ":" .. fn
            if not (P.hooked and P.hooked[key]) then
                local ok, pre, post = pcall(RegisterHook, key, function(ctx)
                    local o = nil
                    pcall(function() o = ctx:get() end)
                    P.hookFired[#P.hookFired + 1] = { menu = hc.menu, fn = fn, obj = o }
                end)
                if not ok then missing = missing + 1 end
                if ok then
                    P.hooked = P.hooked or {}
                    P.hooked[key] = true
                    P.log("hooked %s", key:match("[^/]+$"))
                    local f = io.open(P.HOOKS_FILE, "ab")
                    if f then f:write(key .. "|" .. tostring(pre) .. "|" .. tostring(post) .. "\n"); f:close() end
                end
            end
        end
    end
    if missing == 0 then P.allHooked = true end
end
function P.reportHooks(pc)
    local now = os.clock()
    if #P.hookFired > 0 then
        local list = P.hookFired
        P.hookFired = {}
        for _, h in ipairs(list) do
            local m = P.MENUS[h.menu]
            local nm = h.obj and P.nameOf(h.obj) or "?"
            P.log("CONSTRUCT HOOK FIRED: %s on %s (%s)", h.fn, nm, m.what)
            if h.obj then
                -- act a frame later and again 0.5 s later (the tree may still be filling)
                P.pendingOwners[#P.pendingOwners + 1] = { m = m, obj = h.obj, at = now + 0.02 }
                P.pendingOwners[#P.pendingOwners + 1] = { m = m, obj = h.obj, at = now + 0.5 }
            end
        end
    end
    if #P.pendingOwners > 0 then
        local keep = {}
        for _, po in ipairs(P.pendingOwners) do
            if now >= po.at then
                if P.valid(po.obj) then P.try("inject from hook", P.injectOwner, pc, po.m, po.obj) end
            else
                keep[#keep + 1] = po
            end
        end
        P.pendingOwners = keep
    end
end

function P.checkModsClick(pc)
    local now = os.clock()
    for _, e in pairs(P.injected) do
        if P.valid(e.catcher) and P.valid(e.w) then
            if now - (e.labelAt or 0) >= 0.5 or now < (P.labelFastUntil or 0) then   -- every frame right after a menu opens
                e.labelAt = now
                local t = P.readLabel(e)
                if t ~= e.m.label then
                    if e.labelOK then P.log("%s label was reset to %q; setting it again", e.what, tostring(t)) end
                    P.setLabel(e)
                else
                    e.labelOK = true
                end
            end
            local hv = P.callm(e.catcher, "IsHovered") == true
            local pr = P.callm(e.catcher, "IsPressed") == true
            if hv ~= (e.hovered or false) then
                e.hovered = hv
                P.step("%s entry hovered=%s", e.what, tostring(hv))
                if hv then
                    P.try("keyboard focus", function() e.w:SetKeyboardFocus() end)
                    P.try("user focus", function() e.w:SetUserFocus(pc) end)
                end
            end
            if pr ~= (e.pressed or false) then
                if e.pressed and not pr and hv then
                    P.log("%s entry CLICKED", e.what)
                    if not P.open then P.try("open", P.openMenu, pc) end
                end
                e.pressed = pr
            end
        end
    end
end
-- until the main-menu entry exists: a scan every 3 s (the construct hook usually wins)
function P.startupScan(pc)
    local now = os.clock()
    if P.autoAt and now >= P.autoAt and not P.open then
        P.autoAt = nil
        -- in a heist (e.g. after Ctrl+R) the level scans and the cursor trigger cover the pause menu
        if P.mapName and P.mapName() ~= "mainmenu" then return end
        P.log("auto-adding the entry")
        P.try("inject", P.inject, pc, "startup scan", 1)
        P.autoTries = (P.autoTries or 0) + 1
        local main = false
        for _, e in pairs(P.injected) do if e.m == P.MENUS[1] then main = true end end
        if not main and P.autoTries < 20 then P.autoAt = now + 3 end
    end
end

function P.ownerOf(widget)
    -- widget -> WidgetTree -> owning UserWidget
    local tree = P.callm(widget, "GetOuter")
    return tree and P.callm(tree, "GetOuter") or nil
end
-- the MODS screen
do
    for _, file in ipairs({ "screen.lua" }) do
        local path = P.dir .. "\\Scripts\\" .. file
        local f, err = loadfile(path)
        if f then
            local ok, e2 = pcall(f, P, VIS)
            if not ok then P.log("%s failed: %s", file, tostring(e2)) end
        else
            P.log("%s not loaded: %s", file, tostring(err))
        end
    end
end

-- Reload safety: a flag file means the last copy left the cursor/input mode changed.
P.startup = true
P.autoAt = os.clock() + 8
LoopInGameThreadAfterFrames(1, function()
    if P.startup then
        P.startup = false
        P.step("7a startup: remove stale panels")
        P.try("remove stale", P.removeStale)
        local f = io.open(P.FLAG, "r")
        if f then
            f:close()
            P.log("reload flag found: the previous copy changed the cursor; restoring when the player is known")
            P.pendingRestore = true
        end
    end
    if P.pendingRestore then
        local pc = P.localPC()
        if pc then P.pendingRestore = false; P.changedCursor = true; P.restoreInput(pc, "reload") end
    end
    local ok, err = pcall(P.frame)
    if not ok then P.log("frame error: %s", tostring(err)) end
    return false
end)
P.log("loaded (F10 opens the MODS screen; folder %s)", P.dir)
