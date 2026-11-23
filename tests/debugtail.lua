-- DEBUG tabs: off by default; ModMenu's Debug setting adds a DEBUG tab to mods that publish actions
ModRef = { vars = {} }
function ModRef:SetSharedVariable(k, v) self.vars[k] = v end
function ModRef:GetSharedVariable(k) return self.vars[k] end
ModRef.vars["ModMenu.debug.SentryHeat"] = "heat_up\tHeat +10%\tYour sentries\nbreak\tBreak on next shot\tdesc"
local P = MMP
keybinds.F10(); tick(3)
local function find(name) for i, m in ipairs(P.ui.mods) do if m.name == name then return i, m end end end
local function lastTab() return P.ui.sections[#P.ui.sections].name end
local si, sh = find("SentryHeat")
sh.schema.settings.StyleKey.debug = true          -- a "debug": true setting (the field authors can use)
P.showMod(si)
assert(lastTab() ~= "Debug", "Debug is off by default: no DEBUG tab")
for _, sec in ipairs(P.ui.sections) do for _, sp in ipairs(sec.specs) do
  assert(sp.key ~= "StyleKey", "debug settings must be hidden while Debug is off")
end end
-- the MOD MENU SETTINGS button opens ModMenu's page; switch Debug on there
local mi, mm = find(MMP.selfName)
assert(P.ui.menuBtn, "the MOD MENU SETTINGS button exists")
P.showMod(mi)
local dbgRow
for _, r in ipairs(P.ui.rows) do if r.s.key == "Debug" then dbgRow = r end end
assert(dbgRow and dbgRow.value == "false", "ModMenu page should have the Debug switch, off")
dbgRow.onP.click.click(); tick(30)
assert(mm.doc:get("Debug") == "true", "Debug not saved")
if P.VERBOSE then assert(lastTab() == "Debug", "dev build: ModMenu's own DEBUG tab (tools) should appear")
else assert(lastTab() ~= "Debug", "release: the tools are stripped, so ModMenu has no DEBUG tab") end
P.showMod(si)
assert(lastTab() == "Debug", "SentryHeat should now have a DEBUG tab")
local desc = ""
P.ui.desc.SetText = function(self, v) desc = tostring(v) end
P.showSection(#P.ui.sections)
-- main menu: greyed out, RUN sends nothing
assert(P.ui.rows[2].off == true, "debug rows should be greyed in the main menu")
P.ui.rows[2].runP.click.click(); tick(2)
assert(ModRef.vars["ModMenu.run.SentryHeat"] == nil, "RUN in the main menu must not send")
assert(desc:find("only in a heist"), "main menu note: " .. desc)
-- in a heist (same world object, a heist map name): live
world = obj({ GetFName = function() return { ToString = function() return "Cookie" end } end })
P.showSection(#P.ui.sections)
assert(P.ui.rows[2].off == false, "debug rows should be live in a heist")
assert(#P.ui.rows == 3 and P.ui.rows[1].s.key == "StyleKey", "the debug setting should open the DEBUG tab")
assert(P.ui.rows[2].s.label == "Heat +10%", "mod actions should follow the debug settings")
P.ui.rows[2].runP.click.click(); tick(2)
local req = ModRef.vars["ModMenu.run.SentryHeat"]
assert(req and req:find("^heat_up#"), "no request sent: " .. tostring(req))
ModRef.vars["ModMenu.reply.SentryHeat"] = req .. "\theat +10% on your sentries"
tick(2)
assert(desc == "Heat +10%: heat +10% on your sentries", "answer not shown: " .. desc)
-- four quick presses = four requests, one at a time
local seen = {}
local function modAnswers()
  local r = ModRef.vars["ModMenu.run.SentryHeat"]
  if r and not seen[r] then seen[r] = true; ModRef.vars["ModMenu.reply.SentryHeat"] = r .. "\tok" end
end
for k = 1, 4 do P.ui.rows[2].runP.click.click() end
for k = 1, 60 * 5 do tick(1); if k % 30 == 0 then modAnswers() end end
local n = 0; for _ in pairs(seen) do n = n + 1 end
assert(n == 4, "expected 4 separate requests, got " .. n)
-- no answer: shown after 3 s
P.ui.rows[3].runP.click.click(); tick(60 * 4)
assert(desc:find("no answer within 3 s"), "timeout not shown: " .. desc)
-- Debug off again: tabs gone
P.showMod(mi)
for _, r in ipairs(P.ui.rows) do if r.s.key == "Debug" then dbgRow = r end end
dbgRow.offP.click.click(); tick(30)
P.showMod(si)
assert(lastTab() ~= "Debug", "DEBUG tab should go with Debug off")
assert(not has("FAILED"), "a guarded call failed")
print("DEBUG OK\n")
