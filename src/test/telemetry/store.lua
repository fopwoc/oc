local storeModule =
    require("lib.telemetry.store")

local now = 10
local store = storeModule.create({
  clock = function()
    return now
  end,
})

store:update({
  source = "power_monitor",
  id = "power-main",
  address = "computer-a",
  uptime = 1,
  data = {
    type = "power_monitor",
    name = "Central",
  },
})

store:update({
  source = "power_monitor",
  id = "power-main",
  address = "computer-b",
  uptime = 1,
  data = {
    type = "power_monitor",
    name = "Ore Processing",
  },
})

assert(
  #store:all() == 2,
  "dashboard store should keep same-id metrics from different computers"
)

now = 15

local first = store:update({
  source = "power_monitor",
  id = "power-main",
  address = "computer-a",
  uptime = 2,
  data = {
    type = "power_monitor",
    name = "Central",
  },
})

assert(
  store:age(first) == 0,
  "dashboard store should refresh only the matching sender"
)

print("telemetry store: OK")
