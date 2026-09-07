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
framebuffer.setBackground(frame, 0x0000FF)
framebuffer.write(frame, 1, 1, "A")

framebuffer.setForeground(
  frame,
  color.create(0xFFFFFF, 0.5)
)
framebuffer.writeForeground(frame, 1, 1, "A")

assertEqual(
  frame.foreground[1],
  0x8080FF,
  "semi-transparent foreground over background"
)

assertEqual(
  frame.background[1],
  0x0000FF,
  "transparent foreground preserves background"
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

local layeredFrame = framebuffer.create(1, 1)

framebuffer.setForeground(layeredFrame, 0xFFFFFF)
framebuffer.setBackground(layeredFrame, 0x000000)
framebuffer.write(layeredFrame, 1, 1, "A")

framebuffer.tint(
  layeredFrame,
  1,
  1,
  1,
  1,
  color.create(0xFF0000, 0.5)
)
framebuffer.tint(
  layeredFrame,
  1,
  1,
  1,
  1,
  color.create(0x00FF00, 0.5)
)
framebuffer.tint(
  layeredFrame,
  1,
  1,
  1,
  1,
  color.create(0x0000FF, 0.5)
)

assertEqual(
  layeredFrame.foreground[1],
  0x4060A0,
  "layered color tint"
)

assertEqual(
  color.blend(0x123456, 0xABCDEF),
  0x123456,
  "opaque colors avoid blending"
)

print("color compositing: OK")
