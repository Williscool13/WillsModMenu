-- modmenu_ini: read and edit a mod's settings.ini without disturbing it.
--
-- Pure Lua (no UE4SS calls), so it's tested offline. Guarantees:
--   * parse + serialize with no edits gives back the file byte for byte
--     (comments, column alignment, blank lines, each line's own line ending);
--   * set() changes only the value: the key, the "=", and the comment column
--     stay where they were;
--   * a setting that isn't in the file (the user deleted it to get the
--     default) is appended at the end.
--
-- File format understood (the one our mods use):
--   ; comment line
--   ; --- Section name ---
--   ; -- Sub-header --        (inside a section; two dashes)
--   Key = value   ; description
--
-- Usage:
--   local ini = require("modmenu_ini")
--   local doc = ini.parse(text)          -- or ini.load(path)
--   doc:get("Style")  -> "world"
--   doc:set("Style", "panel")
--   doc:serialize()  -> text             -- or doc:save(path)
--   doc:entries()    -> { { key, value, comment, section }, ... } in file order

local M = {}
local Doc = {}
Doc.__index = Doc

-- Split into lines, keeping each line's ending ("\r\n", "\n" or "" for the last).
local function splitLines(text)
    local out, pos = {}, 1
    while pos <= #text do
        local nl = text:find("\n", pos, true)
        if not nl then
            out[#out + 1] = { body = text:sub(pos), eol = "" }
            break
        end
        local body = text:sub(pos, nl - 1)
        local eol = "\n"
        if body:sub(-1) == "\r" then body, eol = body:sub(1, -2), "\r\n" end
        out[#out + 1] = { body = body, eol = eol }
        pos = nl + 1
    end
    return out
end

-- "Key = value   ; comment" -> parts, or nil if not a setting line.
local function parseSetting(body)
    local semi = body:find(";", 1, true)
    local code = semi and body:sub(1, semi - 1) or body
    local comment = semi and body:sub(semi) or nil
    local lead, key, sep, rest = code:match("^(%s*)([%w_]+)(%s*=%s*)(.*)$")
    if not key then return nil end
    local value, gap = rest:match("^(.-)(%s*)$")
    return { lead = lead, key = key, sep = sep, value = value, gap = gap, comment = comment }
end

function M.parse(text)
    local doc = setmetatable({ lines = splitLines(text), index = {} }, Doc)
    local section, group = nil, nil
    for i, ln in ipairs(doc.lines) do
        local s = parseSetting(ln.body)
        if s then
            s.section, s.group = section, group
            ln.setting = s
            doc.index[s.key:lower()] = i
        else
            local name = ln.body:match("^%s*;%s*%-%-%-+%s*(.-)%s*%-%-%-+%s*$")
            if name and name ~= "" then section, group = name, nil
            else
                -- "; -- Name --": a sub-header inside the current section
                local g = ln.body:match("^%s*;%s*%-%-%s+(.-)%s+%-%-%s*$")
                if g and g ~= "" and not g:find("^%-") then group = g end
            end
        end
    end
    -- the first comment line is the file's description
    local first = doc.lines[1] and doc.lines[1].body:match("^%s*;%s*(.-)%s*$")
    doc.description = first
    -- line ending for appended lines: whatever the file mostly uses
    local crlf, lf = 0, 0
    for _, ln in ipairs(doc.lines) do
        if ln.eol == "\r\n" then crlf = crlf + 1 elseif ln.eol == "\n" then lf = lf + 1 end
    end
    doc.newline = (crlf >= lf and crlf > 0) and "\r\n" or "\n"
    return doc
end

local function render(s)
    return s.lead .. s.key .. s.sep .. s.value .. s.gap .. (s.comment or "")
end

function Doc:get(key)
    local i = self.index[key:lower()]
    return i and self.lines[i].setting.value or nil
end

function Doc:set(key, value)
    value = tostring(value)
    local i = self.index[key:lower()]
    if not i then
        -- Not in the file: append. Make sure the previous last line ends.
        local last = self.lines[#self.lines]
        if last and last.eol == "" then last.eol = self.newline end
        local s = { lead = "", key = key, sep = " = ", value = value, gap = "", comment = nil }
        self.lines[#self.lines + 1] = { body = render(s), eol = self.newline, setting = s }
        self.index[key:lower()] = #self.lines
        return
    end
    local ln = self.lines[i]
    local s = ln.setting
    if s.value == value then return end
    if s.comment then
        -- keep the comment in its column (at least one space before it)
        local width = #s.value + #s.gap
        s.gap = string.rep(" ", math.max(1, width - #value))
    end
    s.value = value
    ln.body = render(s)
end

function Doc:entries()
    local out = {}
    for _, ln in ipairs(self.lines) do
        local s = ln.setting
        if s then
            local desc = s.comment and s.comment:match("^;%s*(.-)%s*$") or nil
            out[#out + 1] = { key = s.key, value = s.value, comment = desc, section = s.section, group = s.group }
        end
    end
    return out
end

function Doc:serialize()
    local parts = {}
    for _, ln in ipairs(self.lines) do parts[#parts + 1] = ln.body .. ln.eol end
    return table.concat(parts)
end

function M.load(path)
    local f, err = io.open(path, "rb")
    if not f then return nil, err end
    local text = f:read("a")
    f:close()
    return M.parse(text)
end

function Doc:save(path)
    -- Write to a temp file first, then replace, so a failed write can't
    -- leave a half-written settings file behind.
    local tmp = path .. ".tmp"
    local f, err = io.open(tmp, "wb")
    if not f then return false, err end
    f:write(self:serialize())
    f:close()
    -- Windows can't rename over an existing file: move the old one aside,
    -- and put it back if the swap fails.
    local bak = path .. ".bak"
    os.remove(bak)
    local hadOld = os.rename(path, bak)
    local ok, err2 = os.rename(tmp, path)
    if not ok then
        if hadOld then os.rename(bak, path) end
        os.remove(tmp)
        return false, err2
    end
    os.remove(bak)
    return true
end

return M
