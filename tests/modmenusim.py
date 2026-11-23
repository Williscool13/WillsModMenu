# Smoke test for the ModMenu mod: run it from a fake Mods folder (real
# settings.ini files next to it), open the MODS screen with F10, check it builds
# rows from both mods, click every row, press Esc, open again and click BACK.
# The engine is faked (no real widgets), so this catches Lua errors and logic
# slips, not looks. Run it on the dev source AND on the release build output.
# Usage: python -I modmenusim.py <fake_mods_dir>     (needs <dir>/WillsModMenu/Scripts)
import lupa.lua54 as lupa, sys, os
mods = os.path.abspath(sys.argv[1]).replace("\\", "/")
main_path = mods + "/WillsModMenu/Scripts/main.lua"
L = lupa.LuaRuntime()
L.execute(r'''
clock = 0; os.clock = function() return clock end
logs = {}
function print(...) local s = table.concat({...}, " "); logs[#logs + 1] = s; io.write(s) end
local function obj(f) f = f or {}; f.__valid = true
  return setmetatable(f, { __index = function(t, k)
    if k == "IsValid" then return function(self) return self.__valid end end
    return function(self, ...) return rawget(t, "__ret_" .. k) end end }) end
_G.obj = obj
world = obj({ GetFName = function() return { ToString = function() return "MainMenu" end } end })
pc = obj({ bShowMouseCursor = true, IsLocalController = function() return true end,
  GetWorld = function() return world end })
buttons = {}
function StaticFindObject(p) return obj({ __path = p }) end
function LoadAsset(p) return obj({ __path = p }) end
local function widget(name)
  local o = obj({ __name = name, Font = {} })
  o.GetFName = function() return { ToString = function() return name end } end
  for _, k in ipairs({ "AddChildToCanvas", "AddChildToVerticalBox", "AddChildToHorizontalBox", "AddChild" }) do
    o[k] = function() return obj({}) end
  end
  if name:find("Back") or name:find("Btn") or name:find("Catcher") then
    o.IsPressed = function(self) return self.p == true end
    o.IsHovered = function(self) return self.h == true end
    buttons[#buttons + 1] = o
  end
  return o
end
function StaticConstructObject(c, outer, name) return widget(name) end
created = 0
wbl = obj({ Create = function(self, ctx, cls, owner) created = created + 1; return widget("Created_" .. tostring(cls.__path):match("[^.]+$")) end })
local sfo = StaticFindObject
StaticFindObject = function(p) if p:find("WidgetBlueprintLibrary") then return wbl end return sfo(p) end
function FindAllOf(c) if c == "PlayerController" then return { pc } end return {} end
function FName(s) return s end
function FText(s) return s end
Key = { F10 = "F10", ESCAPE = "ESCAPE" }
keybinds = {}
function RegisterKeyBind(k, f) keybinds[k] = f end
function RegisterHook() return 1, 1 end
function UnregisterHook() end
loops = {}
function LoopInGameThreadAfterFrames(n, f) loops[#loops + 1] = f end
function tick(k) for i = 1, k do clock = clock + 1/60; for _, f in ipairs(loops) do f() end end end
function IterateGameDirectories() return { Game = { Binaries = { Win64 = { ue4ss = { Mods = MODS_TREE } } } } } end
function has(pat) for _, s in ipairs(logs) do if s:find(pat) then return true end end return false end
''')
def lua_tree(path, depth=0):
    parts = []
    files = []
    for n in sorted(os.listdir(path)):
        full = os.path.join(path, n)
        if os.path.isdir(full):
            if depth < 3:
                parts.append('["%s"] = %s' % (n, lua_tree(full, depth + 1)))
        else:
            files.append('{ __name = "%s" }' % n)
    parts.append("__files = { %s }" % ", ".join(files))
    return "{ " + ", ".join(parts) + " }"
L.execute("MODS_TREE = " + lua_tree(mods))
N_MODS = sum(1 for n in os.listdir(mods) if os.path.isdir(os.path.join(mods, n)) and n.lower() != "shared" and not (n == "WillsModMenu" and not os.path.exists(os.path.join(mods, n, "settings.ini"))))
if "function P.debugEntry" in open(mods + "/WillsModMenu/Scripts/screen.lua", encoding="utf-8").read():
    N_MODS += 1          # dev builds list a DEBUG entry last
L.execute("N_MODS = %d" % N_MODS)
src = open(main_path, encoding="utf-8").read()
L.eval("function(s, n) local f, e = load(s, n); if not f then error(e) end; f() end")(src, "@" + main_path)
L.execute(r'''
tick(30)
keybinds.F10(); tick(3)
assert(has("MODS screen built: " .. N_MODS .. " mods"), "screen not built from all " .. N_MODS .. " mods")
assert(created == 0, "the screen should create no game widgets, created " .. created)
assert(has("showing ") and (has("rows %(") or has("sections")), "rows not built")
-- click catchers after BACK until a row value changes (tabs come first, then rows)
local changedRow = false
local skip = {}                 -- the on/off switches have their own test (toggletail)
for _, rb in ipairs(MMP.ui.buttons) do if rb.row and (rb.row.s.key == "__enabled" or rb.row.s.key == "Debug") then skip[rb.btn] = true end end
for k = #buttons, 5, -1 do      -- newest first: the current rows' click areas
  local b = buttons[k]
  if skip[b] then goto continue end
  b.h = true; b.p = true; tick(1); b.p = false; tick(1); b.h = false; tick(1)
  if has("row %a+ %-> ") then changedRow = true; break end
  ::continue::
end
assert(changedRow, "no row click changed a value")
-- every section of every mod, every click area, a drag, the colour fields
local P = MMP
local clicks = 0
for mi = 1, #P.ui.mods do
  P.showMod(mi)
  for si = 1, #P.ui.sections do
    P.showSection(si)
    for _, b in ipairs(P.ui.buttons) do
      local special = b.row and (b.row.s.key == "__enabled" or (P.ui.mods[mi].name == P.selfName and b.row.s.key == "Debug"))
      if b.kind == "row" and not special then b.click(); clicks = clicks + 1; if b.drag then b.drag() end end
    end
    for _, r in ipairs(P.ui.rows) do if r.poll then r.poll() end end
  end
end
local kinds = {}
for _, s in ipairs(logs) do local k = s:match("row %a+ %-> ") ; if k then kinds[#kinds + 1] = k end end
print("clicked " .. clicks .. " row click areas, " .. #kinds .. " value changes\n")
assert(clicks > 40 and #kinds > 20, "too few clicks/changes")
assert(not has("%) failed:"), "a row builder failed")
assert(not has("frame error"), "frame error")
keybinds.ESCAPE(); tick(3)
assert(has("close MODS screen %(Esc%)"), "Esc did not close")
local n0 = #buttons
keybinds.F10(); tick(3)
local back
for _, b in ipairs(MMP.ui.buttons) do if b.kind == "fixed" then back = b.btn; break end end   -- the first hint: BACK
back.h = true; back.p = true; tick(1); back.p = false; tick(1)
assert(has("close MODS screen %(BACK%)"), "BACK did not close")
tick(600)
assert(not has("frame error"), "frame error")
assert(not has("FAILED"), "a guarded call failed")
print("MODMENU SIM OK (" .. created .. " widgets created)\n")
''')
if len(sys.argv) > 2: L.execute(open(sys.argv[2], encoding='utf-8').read())
