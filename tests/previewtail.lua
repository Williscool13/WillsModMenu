-- HUD position preview: open MethCook's section with PanelX, drag in the frame, release -> saved
local P = MMP
local mouse = { X = 0, Y = 0 }
local wllFake = obj({
  GetMousePositionOnViewport = function() return mouse end,
  GetViewportSize = function() return { X = 2560, Y = 1440 } end,
  GetViewportScale = function() return 2560 / 1920 end })
local sfo0 = StaticFindObject
StaticFindObject = function(p) if p:find("WidgetLayoutLibrary") then return wllFake end return sfo0(p) end
keybinds.F10(); tick(3)
local mi
for i, m in ipairs(P.ui.mods) do if m.name == "MethCook" then mi = i end end
P.showMod(mi)
local si
for i, sec in ipairs(P.ui.sections) do for _, sp in ipairs(sec.specs) do if sp.key == "PanelX" then si = i end end end
assert(si, "no section with PanelX")
P.showSection(si); tick(2)
local pv = P.ui.preview
assert(pv and pv.sel, "preview not built")
assert(#pv.elems == 2, "expected both mods' elements, got " .. #pv.elems)
-- press in the middle of the frame (away from the box) and drag a little
local r = { 0.625, 0.585, 0.30, 0.30 }
local function at(fx, fy) mouse.X = (r[1] + r[3] * fx) * 1920; mouse.Y = (r[2] + r[4] * fy) * 1080 end
at(0.5, 0.5); pv.cat.h = true; pv.cat.p = true; tick(2)
at(0.6, 0.4); tick(2)
assert(P.ui.mods[mi].doc:get("PanelX") == "0.600", "PanelX while dragging: " .. tostring(P.ui.mods[mi].doc:get("PanelX")))
assert(P.ui.mods[mi].doc:get("PanelY") == "0.40", "PanelY while dragging: " .. tostring(P.ui.mods[mi].doc:get("PanelY")))
pv.cat.p = false; tick(30)
assert(has("preview: MethCook PanelX = 0.600, PanelY = 0.40"), "release not logged")
local f = io.open(P.ui.mods[mi].path, "rb"); local txt = f:read("a"); f:close()
assert(txt:find("PanelX%s*=%s*0%.600") and txt:find("PanelY%s*=%s*0%.40"), "not saved to the file")
-- a slider/RESET change moves the box: set the row value and check the anchors follow
assert(not has("preview poll"), "preview poll failed")
-- two elements in one mod: pressing on the second drags it; empty space then moves the selected (second)
local mod = P.ui.mods[mi]
mod.doc:set("Hud2X", "0.200"); mod.doc:set("Hud2Y", "0.200")
mod.schema.preview = { mod.schema.preview, { x = "Hud2X", y = "Hud2Y", size = { 100, 100 }, align = { 0.5, 0.5 }, label = "Second" } }
P.showSection(si); tick(2)
pv = P.ui.preview
assert(#pv.mine == 2 and #pv.elems == 3, "expected 2 own + 1 other element")
at(0.2, 0.2); pv.cat.h = true; pv.cat.p = true; tick(2)
at(0.3, 0.25); tick(2)
pv.cat.p = false; tick(30)
assert(mod.doc:get("Hud2X") == "0.300" and mod.doc:get("Hud2Y") == "0.250", "second element: " .. tostring(mod.doc:get("Hud2X")) .. ", " .. tostring(mod.doc:get("Hud2Y")))
assert(mod.doc:get("PanelX") == "0.600", "the first element moved too")
at(0.9, 0.9); pv.cat.p = true; tick(2); pv.cat.p = false; tick(30)
assert(mod.doc:get("Hud2X") == "0.900" and mod.doc:get("PanelX") == "0.600", "empty-space press should move the selected (second) element")
print("PREVIEW OK\n")
-- the box follows a slider while it's being dragged (before the row saves)
P.ui.mods[mi].schema.preview = P.ui.mods[mi].schema.preview[1]
P.showSection(si); tick(2)
pv = P.ui.preview
local before = pv.sel.last[3]
local row; for _, r in ipairs(P.ui.rows) do if r.s.key == "IconSize" then row = r end end
row.value = "112"; tick(2)                         -- slider moved, row not left yet
assert(math.abs(pv.sel.last[3] - before * 2) < 1e-6, "box did not follow the live Icon Size")
print("PREVIEW LIVE OK\n")
