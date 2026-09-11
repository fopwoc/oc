local clock = {}

-- OpenComputers maps one 20-minute Minecraft day to 86,400 os.time()
-- seconds. Convert that persistent world clock back to elapsed real seconds.
local IN_GAME_SECONDS_PER_REAL_SECOND = 72

function clock.fromInGameSeconds(value)
  assert(
    type(value) == "number",
    "OpenComputers clock value must be numeric"
  )

  return value / IN_GAME_SECONDS_PER_REAL_SECOND
end

function clock.now()
  return clock.fromInGameSeconds(os.time())
end

return clock
