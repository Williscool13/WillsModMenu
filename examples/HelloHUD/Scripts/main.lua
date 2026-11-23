-- HelloHUD: an example mod for Will's Mod Menu (see docs/AUTHOR_GUIDE.md).
-- It draws one line of text on the HUD. Everything about the label comes from
-- settings.ini, and the label updates as soon as the menu changes the file.

local MOD = "HelloHUD"     -- must match the folder name (the menu's signals use it)
local function log(fmt, ...) print("[HelloHUD] " .. string.format(fmt, ...) .. "\n") end

---------------------------------------------------------------------------
-- 1. Settings: defaults here, settings.ini overrides them
---------------------------------------------------------------------------
local CFG = { Text = "Hello, HUD!", Size = 24, Color = "FFFFFF", ToggleKey = "F6", PanelX = 0.5, PanelY = 0.15 }
local DIR = ((debug.getinfo(1, "S").source or ""):gsub("^@", ""):gsub("[/\\]Scripts[/\\][^/\\]*$", ""))

local function loadSettings()
    local f = io.open(DIR .. "\\settings.ini", "r")
    if not f then return end
    for line in f:lines() do
        local k, v = line:gsub(";.*$", ""):match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if k and CFG[k] ~= nil and v ~= "" then
            if type(CFG[k]) == "number" then CFG[k] = tonumber(v) or CFG[k] else CFG[k] = v end
        end
    end
    f:close()
end

---------------------------------------------------------------------------
-- 2. The label: a runtime UMG widget (UserWidget > CanvasPanel > TextBlock)
---------------------------------------------------------------------------
local ui = {}
-- Object names must be unique, also across Ctrl+R reloads (a reused name makes
-- the engine reuse the old object, which garbage collection then removes).
local N, TAG = 0, string.format("%x", math.floor(os.clock() * 1000) % 0xFFFFFF)
local function new(cls, outer)
    N = N + 1
    return StaticConstructObject(StaticFindObject("/Script/UMG." .. cls), outer, FName(MOD .. "_" .. TAG .. "_" .. N))
end
-- settings use sRGB hex (FF8800); UMG wants linear colour
local function linear(hex)
    if not hex:match("^%x%x%x%x%x%x$") then hex = "FFFFFF" end
    local function c(i)
        local x = tonumber(hex:sub(i, i + 1), 16) / 255
        return x <= 0.04045 and x / 12.92 or ((x + 0.055) / 1.055) ^ 2.4
    end
    return { R = c(1), G = c(3), B = c(5), A = 1 }
end

local function build(pc)
    ui.root = new("UserWidget", pc:GetWorld())
    ui.tree = new("WidgetTree", ui.root)
    ui.root.WidgetTree = ui.tree
    local canvas = new("CanvasPanel", ui.tree)
    ui.tree.RootWidget = canvas
    ui.text = new("TextBlock", ui.tree)
    ui.slot = canvas:AddChildToCanvas(ui.text)
    ui.slot:SetAutoSize(true)
    ui.slot:SetAlignment({ X = 0.5, Y = 0.5 })        -- PanelX / PanelY is the label's centre
    ui.root:AddToViewport(10)
end

-- settings -> the label (called after loading and after every reload)
local function apply()
    ui.key = { KeyName = FName(CFG.ToggleKey) }
    if not ui.text then return end
    pcall(function()
        ui.text:SetText(FText(CFG.Text))
        ui.text.Font.Size = CFG.Size
        ui.text:SetColorAndOpacity({ SpecifiedColor = linear(CFG.Color), ColorUseRule = 0 })
        ui.slot:SetAnchors({ Minimum = { X = CFG.PanelX, Y = CFG.PanelY }, Maximum = { X = CFG.PanelX, Y = CFG.PanelY } })
        ui.slot:SetPosition({ X = 0, Y = 0 })
    end)
end

---------------------------------------------------------------------------
-- 3. Live settings: the menu sets "ModMenu.changed.HelloHUD" after each save
---------------------------------------------------------------------------
local MM = { var = "ModMenu.changed." .. MOD, seen = nil, at = 0 }
function MM.check()
    local now = os.clock()
    if now < MM.at then return end
    MM.at = now + 0.5                                   -- twice a second is plenty
    if ModRef == nil then return end
    if MM.debugCheck then MM.debugCheck() end           -- (section 4)
    local ok, v = pcall(ModRef.GetSharedVariable, ModRef, MM.var)
    if not ok or v == nil or v == MM.seen then return end
    MM.seen = v
    loadSettings()
    apply()
    log("settings reloaded: %q, size %d", CFG.Text, CFG.Size)
end

---------------------------------------------------------------------------
-- 4. A debug action for the menu's DEBUG tab (keep these out of release builds)
---------------------------------------------------------------------------
MM.actions = {
    { id = "hi", label = "Say hi", desc = "Changes the label until the next settings change.", fn = function()
        if ui.text then pcall(function() ui.text:SetText(FText("Hi from the DEBUG tab!")) end) end
        return "the label says hi"
    end },
}
function MM.debugCheck()
    if not MM.published then
        local lines = {}
        for _, a in ipairs(MM.actions) do lines[#lines + 1] = a.id .. "\t" .. a.label .. "\t" .. a.desc end
        MM.published = pcall(ModRef.SetSharedVariable, ModRef, "ModMenu.debug." .. MOD, table.concat(lines, "\n"))
    end
    local ok, r = pcall(ModRef.GetSharedVariable, ModRef, "ModMenu.run." .. MOD)
    r = (ok and type(r) == "string") and r or ""
    if MM.lastRun == nil then MM.lastRun = r; return end   -- a request from before a reload is old
    if r == MM.lastRun then return end
    MM.lastRun = r
    local id = r:match("^(.-)#")
    for _, a in ipairs(MM.actions) do
        if a.id == id then
            local ok2, res = pcall(a.fn)
            pcall(ModRef.SetSharedVariable, ModRef, "ModMenu.reply." .. MOD, r .. "\t" .. (ok2 and tostring(res) or "error"))
        end
    end
end

---------------------------------------------------------------------------
-- 5. Main loop (game thread)
---------------------------------------------------------------------------
-- The local player's controller. After a level change the old one stays valid
-- for a while, so look again every 2 s and prefer the one that has a character.
local pcState = { pc = nil, at = 0 }
local function localPC()
    local now = os.clock()
    if now < pcState.at and pcState.pc and pcState.pc:IsValid() then return pcState.pc end
    pcState.at = now + 2
    local best = nil
    for _, c in ipairs(FindAllOf("PlayerController") or {}) do
        if c:IsValid() and c:IsLocalController() then
            if best == nil then best = c end
            local ok, pawn = pcall(function() return c.Pawn end)
            if ok and type(pawn) == "userdata" and pawn:IsValid() then best = c; break end
        end
    end
    pcState.pc = best
    return best
end

local shown, world = true, nil
loadSettings()
apply()
LoopInGameThreadAfterFrames(1, function()
    local ok, err = pcall(function()
        MM.check()
        local pc = localPC()
        if not pc then return end
        local w = pc:GetWorld():GetAddress()
        if w ~= world then                              -- a new level: a new label
            world = w
            ui = {}
            build(pc)
            apply()
        end
        if pc:WasInputKeyJustPressed(ui.key) then
            shown = not shown
            ui.text:SetVisibility(shown and 3 or 1)     -- 3 = HitTestInvisible, 1 = Collapsed
        end
    end)
    if not ok then log("error: %s", tostring(err)) end
    return false
end)
log("loaded: %q, toggle key %s", CFG.Text, CFG.ToggleKey)
