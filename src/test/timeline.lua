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

-- Multi-field records: one commit per sample, per-field aggregates.
local multi = timeline.create({
  resolutions = {
    {window = 60, step = 10},
    {window = 3600, step = 60},
  },
  fields = {
    fill = {aggregates = {"last", "min", "max", "sum"}, precision = 2},
    input = {aggregates = {"sum"}, precision = 0},
  },
})

multi:commit(0, {fill = 0.5, input = 100})
multi:commit(5, {fill = 0.25, input = 300})
multi:commit(10, {fill = 0.75, input = 200.4})

local fill = multi:aggregate(60, 10, "fill")
local input = multi:aggregate(60, 10, "input")

assert(
  fill.count == 3
    and fill.buckets == 2
    and fill.minimum == 0.25
    and fill.maximum == 0.75
    and fill.last == 0.75
    and math.abs(fill.average - 0.5) < 0.0001,
  "aggregate should roll every kept aggregate up over the window"
)

assert(
  math.abs(input.average - 200.1333) < 0.001
    and input.last == nil
    and input.minimum == nil,
  "aggregate should only expose the aggregates a field keeps"
)

assert(
  math.abs(multi:values(60, 10, "input")[6] - 200.4) < 0.0001
    and multi:values(60, 10, "fill")[6] == 0.75,
  "fields without last should chart their average"
)

local restoredMulti = timeline.create({
  resolutions = {
    {window = 60, step = 10},
    {window = 3600, step = 60},
  },
  fields = {
    fill = {aggregates = {"last", "min", "max", "sum"}},
    input = {aggregates = {"sum"}},
  },
  state = multi:export(),
})

local restoredInput = restoredMulti:aggregate(60, 10, "input")

assert(
  restoredInput.count == 3
    and restoredInput.sum == 600
    and restoredMulti:aggregate(60, 10, "fill").minimum == 0.25,
  "multi-field history should round-trip through export with precision applied"
)

local missingField = pcall(function()
  multi:commit(20, {fill = 0.5})
end)

assert(
  not missingField,
  "a record missing a declared field must be rejected"
)

print("timeline: OK")
