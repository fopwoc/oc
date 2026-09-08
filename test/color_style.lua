package.path = "src/?.lua;" .. package.path

local colorStyle = require("lib.components.color_style")

local custom =
    colorStyle.create({
      text = 0xFFFFFF,
      primary = 0x00AAFF,
      success = 0x00FF00,
      bad = 0xFF0000,
    })

assert(
  custom.text == 0xFFFFFF,
  "ColorStyle should preserve text"
)

assert(
  custom.foreground == 0xFFFFFF,
  "text should alias foreground"
)

assert(
  custom.onSurface == 0xFFFFFF,
  "text should alias onSurface"
)

assert(
  custom.primary == 0x00AAFF,
  "ColorStyle should preserve primary"
)

assert(
  custom.action == 0x00AAFF,
  "primary should alias action"
)

assert(
  custom.good == 0x00FF00,
  "success should alias good"
)

assert(
  custom.danger == 0xFF0000,
  "bad should alias danger"
)

local previous = colorStyle.current()
local observed

colorStyle.with(custom, function()
  observed = colorStyle.current()
end)

assert(
  observed == custom,
  "ColorStyle.with should expose the active style"
)

assert(
  colorStyle.current() == previous,
  "ColorStyle.with should restore the previous style"
)

print("color style: OK")
