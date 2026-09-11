package.path = "src/?.lua;" .. package.path

local series = require("lib.utils.series")

local values = {1, 2, 3, 4, 5, 6, 7}
local sampled = series.resample(values, 4)

assert(
  #sampled == 4
    and sampled[1] == 1
    and sampled[2] == 3
    and sampled[3] == 5
    and sampled[4] == 7,
  "series.resample should preserve the newest value in each range"
)

assert(
  series.resample(values, 20) == values,
  "series.resample should preserve short series"
)

local empty = {}

assert(
  series.resample(empty, 3) == empty,
  "series.resample should preserve empty series"
)

local failed = pcall(function()
  series.resample(values, 0)
end)

assert(
  not failed,
  "series.resample should reject a non-positive limit"
)

print("series helpers: OK")
