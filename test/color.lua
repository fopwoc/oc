package.path = "src/?.lua;" .. package.path

local color = require("lib.compose.color")

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

assertEqual(
  color.blend(
    color.create(0xFF0000, 0.5),
    0xFFFFFF
  ),
  0xFF8080,
  "semi-transparent blend"
)

assertEqual(
  color.blend(
    color.create(0xFFFFFF, 0.5),
    0x0000FF
  ),
  0x8080FF,
  "semi-transparent text over solid background"
)

assertEqual(
  color.invert(0xFFFFFF),
  0x000000,
  "inverted white"
)

assertEqual(
  color.contrast(0xFFFFFF, 0xFFFFFF),
  0x000000,
  "contrast chooses dark text on light background"
)

assertEqual(
  color.blend(
    color.create(0x0000FF, 0.5),
    0x000000
  ),
  0x000080,
  "semi-transparent background blend"
)

assertEqual(
  color.blend(
    color.create(0x0000FF, 0.5),
    color.blend(
      color.create(0x00FF00, 0.5),
      color.blend(
        color.create(0xFF0000, 0.5),
        0x000000
      )
    )
  ),
  0x204080,
  "layered color blend"
)

assertEqual(color.blend(0x123456, 0xABCDEF), 0x123456, "opaque colors")

print("color compositing: OK")
