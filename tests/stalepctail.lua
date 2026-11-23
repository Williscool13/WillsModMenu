-- level change with a stale controller: the old one keeps its cursor shown; a new one appears.
-- The pause entry scan must use the new controller (cursor hidden in play, shown on pause).
local n0 = #logs
local function since(pat) local c = 0; for i = n0 + 1, #logs do if logs[i]:find(pat) then c = c + 1 end end; return c end
local heist = obj({ __ret_GetAddress = 2, GetFName = function() return { ToString = function() return "Cookoff" end } end })
world = heist                                  -- the old controller now reports the heist world (still cursor on)
pc.bShowMouseCursor = true
pc.__ret_GetAddress = 70                       -- (real controllers always have an address)
local newPC = obj({ __ret_GetAddress = 77, bShowMouseCursor = false, IsLocalController = function() return true end,
  GetWorld = function() return heist end })
local oldFind = FindAllOf
FindAllOf = function(c) if c == "PlayerController" then return { pc, newPC } end return oldFind(c) end
tick(60 * 5)
assert(since("level changed") >= 1, "no level change")
assert(MMP.pc == newPC, "still using the old controller")
newPC.bShowMouseCursor = true; tick(30)       -- the player pauses
assert(since("pause menu: 0 live list%(s%) %(menu opened%)") == 1, "no pause scan on the new controller's cursor")
print("STALE PC OK\n")
