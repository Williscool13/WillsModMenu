-- the mod list: every folder, tags (PROBLEM / OFF / KEY CLASH / RESTART NEEDED), notices, clashes
local P = MMP
keybinds.F10(); tick(3)
-- the base run clicks every key row, so set the keys this test is about
for _, m in ipairs(P.ui.mods) do
  if m.name == "ClashMod" then P.saveSetting(m, "PanicKey", "F5") end
  if m.name == "SentryHeat" or m.name == "MethCook" then P.saveSetting(m, "ToggleKey", "F7"); P.saveSetting(m, "StyleKey", "F5") end
end
tick(30); P.refreshStatus()
local byName, tagOf = {}, {}
for i, m in ipairs(P.ui.mods) do byName[m.name] = m; tagOf[m.name] = (P.ui.modWidgets[i] or {}).tagText or "" end
for n, t in pairs(tagOf) do print(string.format("  %-22s %s\n", n, t)) end
assert(P.ui.mods[1].hasSettings, "a mod with settings should come first")
local seenOff = false
for _, m in ipairs(P.ui.mods) do
  if m.name == MMP.selfName then -- (opened by its own button, always last)
  elseif m.enabled == false then seenOff = true else assert(not seenOff, "an on mod after an off one: " .. m.name) end
end
local lastM = P.ui.mods[#P.ui.mods]
assert(lastM.name == MMP.selfName and P.ui.modWidgets[#P.ui.mods] == nil and P.ui.menuBtn, "ModMenu: last, no list entry, its own button")
assert(byName.Keybinds.about == "Developer hotkeys (dumps).", "built-in description")
assert(byName.Keybinds.schema.title == "(UE4SS) Keybinds", "UE4SS prefix")
local posPlain, posKey
for i, m in ipairs(P.ui.mods) do if m.name == "PlainMod" then posPlain = i elseif m.name == "Keybinds" then posKey = i end end
assert(posPlain < posKey, "UE4SS's own mods sort after other switched-on mods")
assert(not byName.shared, "shared is a library folder, not a mod")
assert(tagOf.NestedMod:find("PROBLEM"), "nested install not flagged")
assert(tagOf.OffMod == "OFF", "switched-off mod: " .. tagOf.OffMod)
assert(tagOf.ClashMod:find("KEY CLASH"), "ClashMod's F5 clashes with SentryHeat/MethCook")
assert(tagOf.SentryHeat:find("KEY CLASH") and tagOf.MethCook:find("KEY CLASH"), "both share F5 with ClashMod")
assert(tagOf.PlainMod == "" and tagOf.Keybinds == "", "no tags expected")
-- F7 in both SentryHeat and MethCook is a clash (no exceptions); OffMod's F7 doesn't count (off)
assert(#P.keyClashes(byName.MethCook, "ToggleKey") == 1, "F7: SentryHeat only (OffMod is off)")
assert(#P.keyClashes(byName.MethCook, "StyleKey") == 2, "F5: SentryHeat and ClashMod")
-- the nested mod's page opens with the problem
for i, m in ipairs(P.ui.mods) do if m.name == "NestedMod" then P.showMod(i) end end
local first = P.ui.rows[1]
assert(first and first.s.type == "notice" and first.s.label:find("one folder too deep"), "no problem notice")
-- a mod without settings: nothing to save, no REVERT, no errors
for i, m in ipairs(P.ui.mods) do if m.name == "PlainMod" then P.showMod(i) end end
P.saveSetting(byName.PlainMod, "X", "1"); tick(30)
assert(not has("FAILED"), "a guarded call failed")
-- changing the keys apart clears every clash tag
local cm = byName.ClashMod
P.saveSetting(cm, "PanicKey", "F8")
P.saveSetting(byName.MethCook, "ToggleKey", "NONE"); P.saveSetting(byName.MethCook, "StyleKey", "NONE")   -- clashes are warnings only: fix them
tick(30)
local again = {}
for i, m in ipairs(P.ui.mods) do again[m.name] = (P.ui.modWidgets[i] or {}).tagText or "" end
assert(not again.SentryHeat:find("KEY CLASH") and not again.ClashMod:find("KEY CLASH"), "clash tags did not clear")
-- two keys of the same mod on one key: reported too
local sh = byName.SentryHeat
P.saveSetting(sh, "ToggleKey", "F9"); P.saveSetting(sh, "StyleKey", "F9"); tick(30)
local c = P.keyClashes(sh, "ToggleKey")
assert(#c == 1 and c[1].key == "StyleKey" and c[1].name == "this mod", "same-mod clash not reported")
assert(P.clashText(sh, "ToggleKey"):find("this mod %(Style Key%)"), "clash text: " .. tostring(P.clashText(sh, "ToggleKey")))
print("MODLIST OK\n")
