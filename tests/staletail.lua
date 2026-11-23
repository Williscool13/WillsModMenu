-- rows show current values after a tab / mod switch and after the Debug page rebuild
local P = MMP
keybinds.F10(); tick(3)
local function find(name) for i, m in ipairs(P.ui.mods) do if m.name == name then return i, m end end end
local function row(key) for _, r in ipairs(P.ui.rows) do if r.s.key == key then return r end end end
local mi, mc = find("MethCook")
P.showMod(mi)
local r = row("ReadySound")
local was = r.value
local new = (was == "true") and "false" or "true"
if new == "true" then r.onP.click.click() else r.offP.click.click() end
tick(30)
P.showSection(2); tick(2); P.showSection(1); tick(2)
assert(row("ReadySound").value == new, "after a tab switch: " .. tostring(row("ReadySound").value))
local si = find("SentryHeat"); P.showMod(si); tick(2); P.showMod(mi); tick(2)
assert(row("ReadySound").value == new, "after a mod switch: " .. tostring(row("ReadySound").value))
-- Debug on: the page rebuilds and the switch must show On
local ki = find(MMP.selfName); P.showMod(ki)
row("Debug").onP.click.click(); tick(30)
assert(row("Debug").value == "true", "Debug switch shows " .. tostring(row("Debug").value) .. " after the rebuild")
-- the Enabled switch after a mod switch
P.showMod(si); row("__enabled").offP.click.click(); tick(30)
P.showMod(mi); P.showMod(si)
assert(row("__enabled").value == "false", "Enabled switch shows " .. tostring(row("__enabled").value))
row("__enabled").onP.click.click(); tick(30)
print("STALE OK\n")
