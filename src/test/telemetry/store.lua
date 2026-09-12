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

local ambiguousA = store:update({
  source = "a:b",
  id = "c",
  uptime = 1,
  data = {},
})

local ambiguousB = store:update({
  source = "a",
  id = "b:c",
  uptime = 1,
  data = {},
})

assert(
  ambiguousA ~= ambiguousB
    and store:get("a:b", "c") == ambiguousA
    and store:get("a", "b:c") == ambiguousB,
  "telemetry identity fields must not collide when they contain separators"
)

local bounded = storeModule.create({
  capacity = 2,
  clock = function()
    return now
  end,
})

for index = 1, 3 do
  now = index
  bounded:update({
    source = "bounded",
    id = tostring(index),
    uptime = index,
    data = {},
  })
end

assert(
  bounded:size() == 2
    and bounded:get("bounded", "1") == nil
    and bounded:get("bounded", "3") ~= nil,
  "telemetry store should evict the oldest source at capacity"
)

print("telemetry store: OK")
