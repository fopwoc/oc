package.path = "src/?.lua;" .. package.path

local format = require("lib.utils.format")

assert(
  format.grouped("0002003004") == "2,003,004",
  "grouped formatting should preserve exact integer strings"
)

assert(
  format.grouped("0") == "0",
  "grouped formatting should support zero"
)

assert(
  format.energyExact("100000") == "100,000 EU",
  "exact energy formatting should add readable separators"
)

print("format: OK")
