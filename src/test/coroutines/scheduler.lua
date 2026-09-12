local coroutines = require("lib.coroutines")

local clock = 0
local scheduler = coroutines.create({
  now = function()
    return clock
  end,
})

local trace = {}

scheduler:launch(function()
  trace[#trace + 1] = "timer:start"
  coroutines.delay(5)
  trace[#trace + 1] = "timer:after-delay"

  local name, value =
      coroutines.awaitEvent("tick")

  trace[#trace + 1] =
      name .. ":" .. tostring(value)
end)

scheduler:launch(function()
  trace[#trace + 1] = "second:start"
  coroutines.delay(2)
  trace[#trace + 1] = "second:after-delay"
end)

scheduler:run()

assert(
  table.concat(trace, ",")
    == "timer:start,second:start",
  "scheduler should start each ready coroutine once"
)

clock = 2
scheduler:run()

assert(
  trace[3] == "second:after-delay",
  "scheduler should resume elapsed timers"
)

clock = 4
scheduler:run()

assert(
  #trace == 3,
  "scheduler should keep delayed coroutines suspended"
)

scheduler:dispatch("other", 1)

assert(
  #trace == 3,
  "scheduler should ignore unrelated events"
)

clock = 5
scheduler:run()
scheduler:dispatch("tick", 42)

assert(
  trace[4] == "timer:after-delay"
    and trace[5] == "tick:42",
  "scheduler should resume event waiters with the signal values"
)

local cancelledRuns = 0
local cancelled = scheduler:launch(function()
  cancelledRuns = cancelledRuns + 1
  coroutines.delay(1)
  cancelledRuns = cancelledRuns + 1
end)

scheduler:run()
scheduler:cancel(cancelled)
clock = 10
scheduler:run()

assert(
  cancelledRuns == 1,
  "cancelled coroutines should not resume"
)

local invalidScheduler = pcall(function()
  coroutines.create({})
end)

assert(
  not invalidScheduler,
  "scheduler should require a clock"
)

local function failingEffect()
  error("effect exploded")
end

scheduler:launch(failingEffect)

local crashed, message = pcall(scheduler.run, scheduler)

assert(
  not crashed
    and message:find("effect exploded", 1, true)
    and message:find("failingEffect", 1, true),
  "effect errors should keep the coroutine traceback"
)

print("coroutine scheduler: OK")
