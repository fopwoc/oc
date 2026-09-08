package.path = "src/?.lua;" .. package.path

local series = require("lib.utils.series")

local values = {1, 2, 3, 4, 5, 6, 7}
local sampled = series.downsample(values, 4)

assert(
  #sampled == 4
    and sampled[1] == 1
    and sampled[4] == 7,
  "series.downsample should preserve the endpoints"
)

assert(
  series.downsample(values, 20) == values,
  "series.downsample should preserve short series"
)

local first = series.downsample(values, 1)

assert(
  #first == 1 and first[1] == 1,
  "series.downsample should support a single output sample"
)

local empty = {}

assert(
  series.downsample(empty, 3) == empty,
  "series.downsample should preserve empty series"
)

local failed = pcall(function()
  series.downsample(values, 0)
end)

assert(
  not failed,
  "series.downsample should reject a non-positive limit"
)

print("series helpers: OK")
