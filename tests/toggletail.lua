-- the on/off switch: renames enabled.txt <-> enabled.txt.off, tags OFF + RESTART NEEDED, settings.ini untouched
local P = MMP
keybinds.F10(); tick(3)
local function find(name) for i, m in ipairs(P.ui.mods) do if m.name == name then return i, m end end end
local function tag(name) local i = find(name); return P.ui.modWidgets[i].tagText or "" end
local function read(p) local f = io.open(p, "rb"); if not f then return nil end; local t = f:read("a"); f:close(); return t end
local i, sh = find("SentryHeat")
P.showMod(i)
local row = P.ui.rows[1]
assert(row.s.key == "__enabled" and row.value == "true", "first row should be the Enabled switch, on")
local ini0 = read(sh.path)
row.offP.click.click(); tick(30)
assert(read(sh.dir .. "\\enabled.txt") == nil and read(sh.dir .. "\\enabled.txt.off") ~= nil, "not renamed to enabled.txt.off")
assert(sh.enabled == false and row.value == "false", "state not off")
assert(tag("SentryHeat"):find("OFF") and tag("SentryHeat"):find("RESTART NEEDED"), "tags: " .. tag("SentryHeat"))
assert(read(sh.path) == ini0, "settings.ini changed")
row.onP.click.click(); tick(30)
assert(read(sh.dir .. "\\enabled.txt") ~= nil and read(sh.dir .. "\\enabled.txt.off") == nil, "not renamed back")
assert(not tag("SentryHeat"):find("RESTART NEEDED") and not tag("SentryHeat"):find("OFF"), "tags after back on: " .. tag("SentryHeat"))
-- switching an off mod on creates/renames: OffMod has enabled.txt.off
local oi, om = find("OffMod"); P.showMod(oi)
assert(P.ui.rows[1].s.key == "__enabled" and P.ui.rows[1].value == "false", "OffMod switch should be off")
P.ui.rows[1].onP.click.click(); tick(30)
assert(read(om.dir .. "\\enabled.txt") ~= nil and read(om.dir .. "\\enabled.txt.off") == nil, "OffMod not switched on")
-- mods without a switch
local ki = find("Keybinds"); P.showMod(ki)
for _, r in ipairs(P.ui.rows) do assert(r.s.key ~= "__enabled", "mods.txt mods get no switch") end
local li = find("LockedMod"); P.showMod(li)
for _, r in ipairs(P.ui.rows) do assert(r.s.key ~= "__enabled", "allowToggle=false: no switch") end
assert(P.ui.rows[1].s.type ~= "notice", "LockedMod is on: no note needed")
local ni = find("NestedMod"); P.showMod(ni)
for _, r in ipairs(P.ui.rows) do assert(r.s.key ~= "__enabled", "a mod that can't start gets no switch") end
local pi = find("PlainMod"); P.showMod(pi)
assert(P.ui.rows[1].s.key == "__enabled", "a mod without settings still gets the switch")
assert(not has("FAILED"), "a guarded call failed")
print("TOGGLE OK\n")
