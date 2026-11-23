-- free-text settings are typed in; ";" and line breaks are refused; readonly rows have no field
local P = MMP
keybinds.F10(); tick(3)
local mi, tm
for i, m in ipairs(P.ui.mods) do if m.name == "TextMod" then mi, tm = i, m end end
P.showMod(mi)
local function row(key) for _, r in ipairs(P.ui.rows) do if r.s.key == key then return r end end end
local r = row("PlayerName")
assert(r and r.s.type == "text" and r.edit, "PlayerName should be an editable text row")
local typed = "Alice"
r.edit.GetText = function() return { ToString = function() return typed end } end
tick(30)
assert(tm.doc:get("PlayerName") == "Alice", "typed value not saved: " .. tostring(tm.doc:get("PlayerName")))
typed = "Ali;ce"; tick(30)
assert(tm.doc:get("PlayerName") == "Alice", "a ';' must not be saved")
local f = io.open(tm.path, "rb"); local txt = f:read("a"); f:close()
assert(txt:find("PlayerName = Alice ; shown on the HUD", 1, true), "comment column not kept: " .. txt)
local lk = row("Locked")
assert(lk and lk.s.type == "readonly" and not lk.edit, "readonly setting should not be editable")
print("TEXT OK\n")
