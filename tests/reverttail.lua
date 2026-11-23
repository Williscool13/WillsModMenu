-- REVERT follows the mod being shown: change mod A, change mod B, undo A -> B still shows REVERT
local P = MMP
keybinds.F10(); tick(3)
local vis = {}
local rv = P.ui.revert
rv.SetVisibility = function(self, v) vis.last = v end
local function revertShown() return vis.last ~= nil and vis.last ~= 1 end   -- 1 = Collapsed
local A, B = P.ui.mods[1], P.ui.mods[2]
local function change(mod, key, v) P.saveSetting(mod, key, v); tick(30) end
P.showMod(1); local ka = A.entries[1].key; local va = A.doc:get(ka)
change(A, ka, va .. "x")
P.showMod(2); local kb = B.entries[1].key
change(B, kb, B.doc:get(kb) .. "x")
P.showMod(1); change(A, ka, va)             -- A back to how it was
assert(not revertShown(), "A is unchanged: REVERT should be hidden")
P.showMod(2)
assert(revertShown(), "B is still changed: REVERT should show after switching to it")
print("REVERT OK\n")
