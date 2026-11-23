-- the description pane's heading: the open mod's full name; a hovered list entry's name while hovered
local P = MMP
keybinds.F10(); tick(3)
local head = ""
P.ui.descTitle.SetText = function(self, v) head = tostring(v) end
local function find(name) for i, m in ipairs(P.ui.mods) do if m.name == name then return i end end end
local mi, si = find("MethCook"), find("SentryHeat")
P.showMod(mi)
assert(head == "METH LAB HUD", "heading: " .. head)
local entry
for _, b in ipairs(P.ui.buttons) do if b.kind == "mod" and b.btn == nil then end end
-- hover SentryHeat's list entry (its clickable is the mod-kind button for that index)
local n = 0
for _, b in ipairs(P.ui.buttons) do
  if b.kind == "mod" then n = n + 1; if n == si then entry = b end end
end
assert(entry, "no list entry")
entry.hover(true)
assert(head == "SENTRYHEAT", "hovered heading: " .. head)
entry.hover(false)
assert(head == "METH LAB HUD", "back to the open mod: " .. head)
print("HEAD OK\n")
