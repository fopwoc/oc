package.path = "src/?.lua;" .. package.path

local analytics =
    require("lib.production_line.analytics")

local model = analytics.create({
  id = "line",
  name = "Line",
  sampleSeconds = 5,
  mediumWindow = 15 * 60,
  inputs = {
    {
      key = "input",
      name = "example:item",
      capacity = 1000,
    },
  },
})

model:sample(
  0,
  {inputs = {input = 100}}
)

model:sample(
  5,
  {inputs = {input = 250}}
)

local chart =
    model:snapshot(5).inputs[1].chart

assert(
  #chart == 180,
  "production line chart should use fixed sample slots"
)

assert(
  chart[1] == 0
    and math.abs(chart[#chart] - 0.25) < 0.0001,
  "production line chart should right-align the newest sample"
)

local dailyModel = analytics.create({
  id = "daily-line",
  name = "Daily line",
  sampleSeconds = 5,
  mediumWindow = 24 * 60 * 60,
  inputs = {
    {
      key = "input",
      name = "example:item",
      capacity = 1000,
    },
  },
})

dailyModel:sample(
  0,
  {inputs = {input = 100}}
)

dailyModel:sample(
  60,
  {inputs = {input = 250}}
)

local dailyChart =
    dailyModel:snapshot(60).inputs[1].chart

assert(
  #dailyChart == 96
    and dailyChart[1] == 0
    and math.abs(dailyChart[#dailyChart] - 0.25) < 0.0001,
  "production line chart should use minute slots for long windows"
)

local keyed = model:chart(model.inputs[1].key, 60 * 60, 5)

assert(
  #keyed == 60
    and math.abs(keyed[#keyed] - chart[#chart]) < 0.0001,
  "chart(key, window) should serve any timeline window for a resource"
)

assert(
  #model:chart("missing", 60, 5) == 0,
  "unknown resources produce an empty chart"
)

print("production line chart: OK")
