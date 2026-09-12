package.path = "src/?.lua;" .. package.path

local decimal = require("lib.utils.decimal")
local analytics = require("lib.power_monitor.analytics")

assert(
  decimal.ratio("900000000000000000", "1000000000000000000") == 0.9,
  "decimal ratio should handle large absolute energy values"
)

assert(
  decimal.compact("1048576000000", "EU") == "1.05 TEU",
  "decimal compact formatting should preserve large energy scales"
)

assert(
  decimal.compact("0", "EU") == "0 EU",
  "decimal compact formatting should separate zero from its unit"
)

local persisted
local now = 0
local model = analytics.create(
  {
    name = "Power",
    id = "power-main",
  },
  {
    settings = {
      historyBucketSeconds = 60,
      depletingEtaSeconds = 100,
      depletingRecoveryEtaSeconds = 120,
    },
    now = function()
      return now
    end,
    persist = function(state)
      persisted = state
    end,
  }
)

model:sample(
  {
    stored = "1000000",
    capacity = "10000000",
    input = 1000,
    output = 1000,
  },
  0
)

model:sample(
  {
    stored = "900000",
    capacity = "10000000",
    input = 0,
    output = 100,
  },
  5
)

local draining = model:snapshot(5)

assert(
  draining.fill == 0.09
    and draining.net == -100
    and draining.state == "DRAINING",
  "negative sustainable flow should enter DRAINING"
)

model:sample(
  {
    stored = "9000",
    capacity = "10000000",
    input = 0,
    output = 100,
  },
  10
)

local depleting = model:snapshot(10)

assert(
  depleting.state == "DEPLETING"
    and depleting.etaSeconds > 0
    and depleting.etaSeconds <= 100,
  "short ETA should enter DEPLETING and use ticks per second"
)

model:sample(
  {
    stored = "9000",
    capacity = "10000000",
    input = 100,
    output = 100,
  },
  60
)

local history = model:historyStats()

assert(
  persisted
    and history.count == 2
    and math.abs(history.minimumFill - 0.0009) < 0.000001,
  "minute transitions should persist bounded aggregate history"
)

local telemetry = model:telemetry(60)

assert(
  telemetry.type == "power_monitor"
    and telemetry.id == "power-main"
    and telemetry.storages == nil
    and telemetry.historyBuckets == nil,
  "telemetry should expose one compact power metric"
)

assert(
  #model:chart(15 * 60, 60) == 180,
  "short history chart should use fixed five-second timeline slots"
)

print("power monitor analytics: OK")
