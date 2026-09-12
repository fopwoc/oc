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

return {
  unicode = unicode,
}
