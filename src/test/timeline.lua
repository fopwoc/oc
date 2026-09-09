package.path = "src/?.lua;" .. package.path

local timeline = require("lib.timeline")

local history = timeline.create({
  reducer = "last",
})

history:commit(0, 0.25)
history:commit(5, 0.5)
history:commit(10, 0.75)

local shortValues =
    history:values(15 * 60, 10)

assert(
  #shortValues == 180,
  "timeline should retain fixed five-second slots for 15 minutes"
)

assert(
  shortValues[1] == 0
    and math.abs(shortValues[#shortValues] - 0.75) < 0.0001,
  "timeline should keep leading empty history and newest data at right"
)

local boundaryValues =
    history:values(15 * 60, 11)

assert(
  math.abs(boundaryValues[178] - 0.25) < 0.0001
    and math.abs(boundaryValues[179] - 0.5) < 0.0001
    and math.abs(boundaryValues[180] - 0.75) < 0.0001,
  "timeline buckets should stay stable between clock ticks"
)

local gapHistory = timeline.create({
  resolutions = {
    {window = 20, step = 5},
  },
})

gapHistory:commit(0, 0.25)
gapHistory:commit(10, 0.75)

local gapValues =
    gapHistory:values(20, 15)

assert(
  math.abs(gapValues[1] - 0.25) < 0.0001
    and math.abs(gapValues[2] - 0.25) < 0.0001
    and math.abs(gapValues[3] - 0.75) < 0.0001
    and math.abs(gapValues[4] - 0.75) < 0.0001,
  "timeline should carry the last value across missing buckets"
)

local hourlyValues =
    history:values(60 * 60, 10)

assert(
  #hourlyValues == 60
    and hourlyValues[1] == 0
    and math.abs(hourlyValues[#hourlyValues] - 0.75) < 0.0001,
  "timeline should use minute slots for one hour"
)

local dailyValues =
    history:values(24 * 60 * 60, 10)

assert(
  #dailyValues == 96
    and dailyValues[1] == 0
    and math.abs(dailyValues[#dailyValues] - 0.75) < 0.0001,
  "timeline should use fifteen-minute slots for one day"
)

local restored = timeline.create({
  state = history:export(),
})

local restoredValues =
    restored:values(15 * 60, 10)

assert(
  math.abs(restoredValues[#restoredValues] - 0.75) < 0.0001,
  "timeline should restore serialized history"
)

print("timeline: OK")
