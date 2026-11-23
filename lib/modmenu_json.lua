-- modmenu_json: a small JSON decoder (objects, arrays, strings, numbers,
-- true/false/null) for settings.schema.json files. Pure Lua.
--   local json = require("modmenu_json")   -- or dofile(...)
--   local t, err = json.decode(text)        -- nil + message on bad input
local M = {}

local function decode(s)
    local pos = 1
    local function err(msg) error(string.format("%s at character %d", msg, pos), 0) end
    local function ws()
        while true do
            local c = s:sub(pos, pos)
            if c == " " or c == "\t" or c == "\r" or c == "\n" then pos = pos + 1
            elseif s:sub(pos, pos + 1) == "//" then             -- tolerate // comments
                local nl = s:find("\n", pos, true); pos = nl and nl + 1 or #s + 1
            else return end
        end
    end
    local value
    local function str()
        pos = pos + 1
        local out = {}
        while true do
            local c = s:sub(pos, pos)
            if c == "" then err("unterminated string") end
            if c == '"' then pos = pos + 1; return table.concat(out) end
            if c == "\\" then
                local e = s:sub(pos + 1, pos + 1)
                local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
                if map[e] then out[#out + 1] = map[e]; pos = pos + 2
                elseif e == "u" then
                    local hex = s:sub(pos + 2, pos + 5)
                    local cp = tonumber(hex, 16) or err("bad \\u escape")
                    out[#out + 1] = utf8.char(cp); pos = pos + 6
                else err("bad escape") end
            else
                out[#out + 1] = c; pos = pos + 1
            end
        end
    end
    local function num()
        local a, b = s:find("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
        if not a then err("bad number") end
        local n = tonumber(s:sub(a, b)) or err("bad number")
        pos = b + 1
        return n
    end
    function value()
        ws()
        local c = s:sub(pos, pos)
        if c == "{" then
            pos = pos + 1
            local t = {}
            ws()
            if s:sub(pos, pos) == "}" then pos = pos + 1; return t end
            while true do
                ws()
                if s:sub(pos, pos) ~= '"' then err("expected a key") end
                local k = str()
                ws()
                if s:sub(pos, pos) ~= ":" then err("expected ':'") end
                pos = pos + 1
                t[k] = value()
                ws()
                local d = s:sub(pos, pos)
                pos = pos + 1
                if d == "}" then return t end
                if d ~= "," then err("expected ',' or '}'") end
                ws()
                if s:sub(pos, pos) == "}" then pos = pos + 1; return t end   -- trailing comma
            end
        elseif c == "[" then
            pos = pos + 1
            local t = {}
            ws()
            if s:sub(pos, pos) == "]" then pos = pos + 1; return t end
            while true do
                t[#t + 1] = value()
                ws()
                local d = s:sub(pos, pos)
                pos = pos + 1
                if d == "]" then return t end
                if d ~= "," then err("expected ',' or ']'") end
                ws()
                if s:sub(pos, pos) == "]" then pos = pos + 1; return t end
            end
        elseif c == '"' then return str()
        elseif s:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
        elseif s:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
        elseif s:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil
        elseif c:match("[-%d]") then return num()
        end
        err("unexpected '" .. c .. "'")
    end
    local v = value()
    ws()
    if pos <= #s then err("trailing text") end
    return v
end

function M.decode(s)
    if s:sub(1, 3) == "\239\187\191" then s = s:sub(4) end   -- UTF-8 BOM
    local ok, v = pcall(decode, s)
    if ok then return v end
    return nil, v
end

function M.load(path)
    local f, e = io.open(path, "rb")
    if not f then return nil, e end
    local s = f:read("a"); f:close()
    return M.decode(s)
end

return M
