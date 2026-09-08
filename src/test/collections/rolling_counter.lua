local rollingCounter =
    require("lib.collections.rolling_counter")

local history = rollingCounter.create({
  windowSeconds = 3600,
  capacity = 4,
})

history:record(0)
history:record(100)
history:record(3599)
history:record(3601)

assert(
  history:count(3601) == 3
    and history:perHour(3601) == 3,
  "completion history should count only recorded successful completions"
)

assert(
  history:count(7200) == 1,
  "completion history should expire completions outside the rolling hour"
)

history:record(7200)
history:record(7201)
history:record(7202)

assert(
  history:size() == 4,
  "completion history should remain bounded"
)

print("rolling counter: OK")
