-- heist: no timed scans; the pause entry is looked for when the cursor appears (+2 retries), pause class only
local n0 = #logs
world = obj({ __ret_GetAddress = 2, GetFName = function() return { ToString = function() return "BranchBank" end } end })
pc.bShowMouseCursor = false
tick(60 * 20)                                    -- 20 s after the level change: no scans at all
local function since(pat) local c = 0; for i = n0 + 1, #logs do if logs[i]:find(pat) then c = c + 1 end end; return c end
assert(since("level changed") == 1, "no level change seen")
assert(since("live list") == 0, "a timed scan ran in the heist")
pc.bShowMouseCursor = true; tick(60)             -- the pause menu opens
assert(since("pause menu: 0 live list%(s%) %(menu opened%)") == 1, "no scan when the menu opened")
assert(since("menu opened, retry") == 2, "expected 2 retries, got " .. since("menu opened, retry"))
assert(since("main menu: .*live list") == 0, "searched the main menu class in a heist")
print("HEIST SCANS OK\n")
