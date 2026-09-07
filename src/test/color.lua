local color = require("lib.compose.color")
local framebuffer = require("lib.compose.framebuffer")

local function assertEqual(actual, expected, message)
  assert(
    actual == expected,
    message
      .. ": expected "
      .. string.format("0x%06X", expected)
      .. ", got "
      .. string.format("0x%06X", actual)
  )
end

local frame = framebuffer.create(2, 1)

framebuffer.setForeground(frame, 0xFFFFFF)
framebuffer.setBackground(frame, 0x000000)
framebuffer.write(frame, 1, 1, "A")

framebuffer.setForeground(
  frame,
  color.create(0xFF0000, 0.5)
)
framebuffer.writeForeground(frame, 1, 1, "A")

assertEqual(
  frame.foreground[1],
  0xFF8080,
  "semi-transparent foreground"
)

framebuffer.setBackground(
  frame,
  color.create(0x0000FF, 0.5)
)
framebuffer.write(frame, 2, 1, "B")

assertEqual(
  frame.background[2],
  0x000080,
  "semi-transparent background"
)

framebuffer.tint(
  frame,
  1,
  1,
  1,
  1,
  color.create(0xFF0000, 0.5)
)
framebuffer.tint(
  frame,
  1,
  1,
  1,
  1,
  color.create(0x00FF00, 0.5)
)
framebuffer.tint(
  frame,
  1,
  1,
  1,
  1,
  color.create(0x0000FF, 0.5)
)

assertEqual(
  frame.foreground[1],
  0x405090,
  "layered color tint"
)

assertEqual(
  color.blend(0x123456, 0xABCDEF),
  0x123456,
  "opaque colors avoid blending"
)

print("color compositing: OK")
