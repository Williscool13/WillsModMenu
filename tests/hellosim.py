# Smoke test for examples/HelloHUD (fake engine): builds the label from
# settings.ini, applies a live change after the menu's signal, toggles with the
# key, answers a debug action.
# Usage: python -I hellosim.py <scratch_dir>     (run from the repo root)
import lupa.lua54 as lupa, os, shutil, sys
work = os.path.abspath(sys.argv[1])
dst = os.path.join(work, "HelloHUD")
if os.path.isdir(dst):
    shutil.rmtree(dst)
shutil.copytree("examples/HelloHUD", dst)
L = lupa.LuaRuntime()
L.execute(r'''
clock = 0; os.clock = function() return clock end
logs = {}; texts = {}; vis = {}
function print(...) local s = table.concat({...}, " "); logs[#logs + 1] = s; io.write(s) end
local function obj(f) f = f or {}
  return setmetatable(f, { __index = function(t, k)
    if k == "IsValid" then return function() return true end end
    return function(self, ...) return rawget(t, "__ret_" .. k) end end }) end
local function widget(name)
  local o = obj({ __name = name, Font = {} })
  o.AddChildToCanvas = function() return obj({}) end
  o.SetText = function(self, t) texts[#texts + 1] = t end
  o.SetVisibility = function(self, v) vis[#vis + 1] = v end
  return o
end
function StaticFindObject(p) return obj({ __path = p }) end
function StaticConstructObject(c, outer, name) return widget(name) end
function FName(s) return s end
function FText(s) return s end
world = obj({ __ret_GetAddress = 1 })
keyDown = nil
pc = obj({ GetWorld = function() return world end, IsLocalController = function() return true end,
  WasInputKeyJustPressed = function(self, k) return k.KeyName == keyDown end })
function FindAllOf(c) if c == "PlayerController" then return { pc } end return {} end
ModRef = { vars = {} }
function ModRef:SetSharedVariable(k, v) self.vars[k] = v end
function ModRef:GetSharedVariable(k) return self.vars[k] end
loops = {}
function LoopInGameThreadAfterFrames(n, f) loops[#loops + 1] = f end
function tick(k) for i = 1, k do clock = clock + 1/60; for _, f in ipairs(loops) do f() end end end
function has(p) for _, s in ipairs(logs) do if s:find(p) then return true end end return false end
''')
main = os.path.join(dst, "Scripts", "main.lua").replace("\\", "/")
L.execute('dofile("%s")' % main)
ini = os.path.join(dst, "settings.ini")
L.execute(r'''
tick(30)
assert(texts[#texts] == "Hello, HUD!", "label text from settings.ini: " .. tostring(texts[#texts]))
assert(ModRef.vars["ModMenu.debug.HelloHUD"], "debug actions not published")
''')
# the menu edits the file and signals
s = open(ini, "rb").read().decode().replace("Hello, HUD!", "Changed live")
open(ini, "wb").write(s.encode())
L.execute(r'''
ModRef.vars["ModMenu.changed.HelloHUD"] = 1.5
tick(60)
assert(texts[#texts] == "Changed live", "live change not applied: " .. tostring(texts[#texts]))
keyDown = "F6"; tick(1); keyDown = nil; tick(1)
assert(vis[#vis] == 1, "F6 should hide the label")
ModRef.vars["ModMenu.run.HelloHUD"] = "hi#1.0"; tick(60)
assert(texts[#texts] == "Hi from the DEBUG tab!", "debug action not run")
assert(ModRef.vars["ModMenu.reply.HelloHUD"] == "hi#1.0\tthe label says hi", "no reply: " .. tostring(ModRef.vars["ModMenu.reply.HelloHUD"]))
assert(not has("error:"), "an error was logged")
print("HELLOHUD OK\n")
''')
