package.path = "src/?.lua;" .. package.path

local clock = require("lib.utils.clock")

assert(
  clock.fromInGameSeconds(86400) == 1200,
  "one Minecraft day should represent twenty real minutes"
)

local first = clock.now()
local second = clock.now()

assert(
  type(first) == "number"
    and second >= first,
  "clock.now should be monotonic within a session"
)

print("clock: OK")
