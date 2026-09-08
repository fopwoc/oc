package.path = "src/?.lua;" .. package.path

local format = require("lib.utils.format")

assert(
  format.number(1234567) == "1,234,567",
  "format.number should group thousands"
)

assert(
  format.number(-1234.9) == "-1,235",
  "format.number should floor negative values"
)

assert(
  format.percent(nil) == "--"
    and format.percent(75) == "75%",
  "format.percent should represent known and unknown values"
)

assert(
  format.rate(2) == "120/m"
    and format.rate(nil) == "--",
  "format.rate should convert per-second values"
)

assert(
  format.amount(1200, 5000) == "1,200/5,000"
    and format.amount(1200) == "1,200/--",
  "format.amount should include optional capacity"
)

assert(
  format.duration(3660) == "1h 01m"
    and format.duration(nil) == "--",
  "format.duration should use compact elapsed time"
)

print("format helpers: OK")
