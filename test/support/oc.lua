-- Host-side stand-ins for the OpenComputers libraries that pure tests touch.
-- Installed into package.preload so a test can still override one locally.

local function wide(codepoint)
  return (codepoint >= 0x1100 and codepoint <= 0x115F)
    or (codepoint >= 0x2E80 and codepoint <= 0xA4CF)
    or (codepoint >= 0xAC00 and codepoint <= 0xD7A3)
    or (codepoint >= 0xF900 and codepoint <= 0xFAFF)
    or (codepoint >= 0xFE30 and codepoint <= 0xFE4F)
    or (codepoint >= 0xFF00 and codepoint <= 0xFF60)
    or (codepoint >= 0xFFE0 and codepoint <= 0xFFE6)
    or (codepoint >= 0x1F300 and codepoint <= 0x1FAFF)
    or (codepoint >= 0x20000 and codepoint <= 0x3FFFD)
end

local unicode = {}

function unicode.len(value)
  return utf8.len(value) or #value
end

function unicode.sub(value, first, last)
  local length = unicode.len(value)

  if first < 0 then
    first = length + first + 1
  end

  last = last or -1

  if last < 0 then
    last = length + last + 1
  end

  if first < 1 then
    first = 1
  end

  if last > length then
    last = length
  end

  if first > last then
    return ""
  end

  local startByte = utf8.offset(value, first)
  local endByte = utf8.offset(value, last + 1)

  return value:sub(startByte, (endByte or #value + 1) - 1)
end

function unicode.charWidth(value)
  local codepoint = utf8.codepoint(value, 1)

  return wide(codepoint) and 2 or 1
end

function unicode.wlen(value)
  local width = 0

  for _, codepoint in utf8.codes(value) do
    width = width + (wide(codepoint) and 2 or 1)
  end

  return width
end

if not package.loaded.unicode and not package.preload.unicode then
  package.preload.unicode = function()
    return unicode
  end
end


-- OpenOS serialization, reproduced byte-for-byte for size measurements.
local serialization = {}

local keywords = {}

for _, keyword in ipairs({
  "and", "break", "do", "else", "elseif", "end", "false", "for",
  "function", "goto", "if", "in", "local", "nil", "not", "or",
  "repeat", "return", "then", "true", "until", "while",
}) do
  keywords[keyword] = true
end

function serialization.serialize(value)
  local seen = {}
  local parts = {}

  local function recurse(current)
    local kind = type(current)

    if kind == "number" then
      if current ~= current then
        parts[#parts + 1] = "0/0"
      elseif current == math.huge then
        parts[#parts + 1] = "math.huge"
      elseif current == -math.huge then
        parts[#parts + 1] = "-math.huge"
      else
        parts[#parts + 1] = tostring(current)
      end
    elseif kind == "string" then
      parts[#parts + 1] =
          (string.format("%q", current):gsub("\\\n", "\\n"))
    elseif kind == "nil" or kind == "boolean" then
      parts[#parts + 1] = tostring(current)
    elseif kind == "table" then
      assert(not seen[current], "tables with cycles are not supported")
      seen[current] = true

      local index = 1
      local first = true

      parts[#parts + 1] = "{"

      for key, item in pairs(current) do
        if not first then
          parts[#parts + 1] = ","
        end

        first = false

        if type(key) == "number" and key == index then
          index = index + 1
          recurse(item)
        else
          if type(key) == "string"
              and not keywords[key]
              and key:match("^[%a_][%w_]*$")
          then
            parts[#parts + 1] = key
          else
            parts[#parts + 1] = "["
            recurse(key)
            parts[#parts + 1] = "]"
          end

          parts[#parts + 1] = "="
          recurse(item)
        end
      end

      seen[current] = nil
      parts[#parts + 1] = "}"
    else
      error("unsupported type: " .. kind)
    end
  end

  recurse(value)

  return table.concat(parts)
end

function serialization.unserialize(text)
  local chunk, err = load("return " .. text, "=data", "t", {math = math})

  if not chunk then
    return nil, err
  end

  local ok, result = pcall(chunk)

  if not ok then
    return nil, result
  end

  return result
end

-- A Unix-backed subset of the OpenOS filesystem API rooted in a scratch
-- directory, so storage tests can run against real files on the host.
local root = (os.getenv("TMPDIR") or "/tmp"):gsub("/+$", "")
  .. "/oc-host-tests"

local function quote(path)
  return "'" .. path:gsub("'", "'\\''") .. "'"
end

local filesystem = {}

function filesystem.concat(...)
  local joined = table.concat({...}, "/")
  return (joined:gsub("/+", "/"))
end

function filesystem.canonical(path)
  local segments = {}

  for segment in path:gmatch("[^/]+") do
    if segment == ".." then
      segments[#segments] = nil
    elseif segment ~= "." then
      segments[#segments + 1] = segment
    end
  end

  return "/" .. table.concat(segments, "/")
end

function filesystem.path(path)
  return (path:match("^(.*)/[^/]*$") or "")
end

function filesystem.isDirectory(path)
  local handle = io.open(path .. "/.", "r")

  if not handle then
    return false
  end

  handle:close()
  return true
end

function filesystem.exists(path)
  if filesystem.isDirectory(path) then
    return true
  end

  local handle = io.open(path, "r")

  if not handle then
    return false
  end

  handle:close()
  return true
end

function filesystem.size(path)
  local handle = io.open(path, "rb")

  if not handle then
    return 0
  end

  local size = handle:seek("end")
  handle:close()
  return size or 0
end

function filesystem.makeDirectory(path)
  return os.execute("mkdir -p " .. quote(path)) == true
end

function filesystem.remove(path)
  return os.execute("rm -rf " .. quote(path)) == true
end

function filesystem.rename(from, to)
  return os.rename(from, to)
end

function filesystem.get()
  return {
    spaceTotal = function()
      return 1024 * 1024
    end,
    spaceUsed = function()
      return 0
    end,
  }, root
end

local shell = {}

function shell.getWorkingDirectory()
  return root
end

for name, module in pairs({
  serialization = serialization,
  filesystem = filesystem,
  shell = shell,
}) do
  if not package.loaded[name] and not package.preload[name] then
    package.preload[name] = function()
      return module
    end
  end
end

filesystem.makeDirectory(root)

return {
  unicode = unicode,
  serialization = serialization,
  filesystem = filesystem,
  shell = shell,
  root = root,
}
