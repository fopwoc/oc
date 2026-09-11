package.path = "src/?.lua;" .. package.path

local clock = require("lib.utils.clock")

assert(
  clock.fromInGameSeconds(86400) == 1200,
  "one Minecraft day should represent twenty real minutes"
)

print("clock: OK")
