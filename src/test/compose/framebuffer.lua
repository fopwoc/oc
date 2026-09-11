local previousUnicode = package.loaded.unicode
local previousUnicodeLoader = package.preload.unicode

package.loaded.unicode = nil
package.preload.unicode = function()
  return {
    len = function(value)
      return value == "界" and 1 or #value
    end,
    sub = function(value, first, last)
      if value == "界" and first == 1 and last == 1 then
        return value
      end

      return value:sub(first, last)
    end,
    charWidth = function(value)
      return value == "界" and 2 or 1
    end,
  }
end

package.loaded["lib.compose.framebuffer"] = nil

local framebuffer = require("lib.compose.framebuffer")

local frame = framebuffer.create(4, 1)

framebuffer.set(frame, 1, 1, "界")
framebuffer.set(frame, 1, 1, "A")

assert(
  frame.chars[1] == "A" and frame.chars[2] == " ",
  "narrow text should clear the continuation of an overlapped wide glyph"
)

framebuffer.set(frame, 1, 1, "界")
framebuffer.set(frame, 2, 1, "B")

assert(
  frame.chars[1] == " " and frame.chars[2] == "B",
  "drawing over a continuation cell should clear its wide glyph lead"
)

framebuffer.set(frame, 2, 1, "界")

assert(
  frame.chars[1] == " "
    and frame.chars[2] == "界"
    and frame.chars[3] == false,
  "a shifted wide glyph should replace every overlapping glyph cell"
)

package.loaded["lib.compose.framebuffer"] = nil
package.loaded.unicode = previousUnicode
package.preload.unicode = previousUnicodeLoader

print("framebuffer overlap: OK")
