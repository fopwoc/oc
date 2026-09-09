package.path = "src/?.lua;" .. package.path

local series = require("lib.utils.series")

local values = series.resample(
  {1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
  4
)

assert(
  #values == 4
    and values[1] == 2
    and values[2] == 5
    and values[3] == 7
    and values[4] == 10,
  "series resampling should preserve the newest value in each bucket"
)

print("series: OK")
