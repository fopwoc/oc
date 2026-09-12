local clock = {}

-- OpenComputers maps one 20-minute Minecraft day to 86,400 os.time()
-- seconds. Convert that persistent world clock back to elapsed real seconds.
local IN_GAME_SECONDS_PER_REAL_SECOND = 72

local anchor = nil

function clock.fromInGameSeconds(value)
  assert(
    type(value) == "number",
    "OpenComputers clock value must be numeric"
  )

  return value / IN_GAME_SECONDS_PER_REAL_SECOND
end

local function monotonic()
  local ok, computer = pcall(require, "computer")

  if ok and type(computer.uptime) == "function" then
    return computer.uptime()
  end

  return os.clock()
end

-- The world clock is only read once, at startup. After that, time advances
-- with computer.uptime(), so `/time set`, sleeping through the night, or a
-- frozen daylight cycle cannot jump or stall persisted history mid-session.
-- Restarts re-anchor to the world clock, which is what keeps timestamps
-- comparable across reboots.
function clock.now()
  if not anchor then
    anchor = {
      world = clock.fromInGameSeconds(os.time()),
      uptime = monotonic(),
    }
  end

  return anchor.world + (monotonic() - anchor.uptime)
end

return clock
