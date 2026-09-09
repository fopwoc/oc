package.path = "src/?.lua;" .. package.path

local analytics =
    require("lib.power_monitor.analytics")

local model = analytics.create(
  {
    id = "chart",
    name = "Chart",
  },
  {
    settings = {
      sampleSeconds = 5,
    },
  }
)

model:sample(
  {
    stored = "100",
    capacity = "1000",
    input = 1,
    output = 0,
  },
  0
)

model:sample(
  {
    stored = "200",
    capacity = "1000",
    input = 1,
    output = 0,
  },
  5
)

model:sample(
  {
    stored = "300",
    capacity = "1000",
    input = 1,
    output = 0,
  },
  10
)

local values =
    model:chart(15 * 60, 10)

assert(
  #values == 180,
  "short chart should use fixed five-second slots"
)

assert(
  values[1] == 0
    and math.abs(values[#values] - 0.3) < 0.0001,
  "chart should fill missing history with zero and keep newest data at right"
)

local longValues =
    model:chart(24 * 60 * 60, 10)

assert(
  #longValues == 96
    and longValues[1] == 0
    and math.abs(longValues[#longValues] - 0.3) < 0.0001,
  "long chart should use fixed fifteen-minute slots and right-align current data"
)

print("power monitor chart: OK")
