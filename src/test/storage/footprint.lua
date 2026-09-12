-- Writes the largest records every persisting metric can produce through the
-- real storage layer, asserts they stay inside the disk budget documented in
-- ARCHITECTURE.md, and removes them again even when an assertion fails.

local filesystem = require("filesystem")
local shell = require("shell")
local storage = require("lib.storage.store")
local powerAnalytics = require("lib.power_monitor.analytics")
local incidentDashboard = require("lib.telemetry.incidents.dashboard")

local POWER_BUDGET = 128 * 1024
local INCIDENT_BUDGET = 24 * 1024

local SAMPLE_SECONDS = 5
local HOURS = 25

local namespaces = {
  "__footprint_power__",
  "__footprint_dashboard__",
}

local dataRoot = filesystem.concat(
  shell.getWorkingDirectory(),
  ".data"
)

local function cleanup()
  for _, namespace in ipairs(namespaces) do
    local path = filesystem.concat(dataRoot, namespace)

    if filesystem.exists(path) then
      filesystem.remove(path)
    end
  end
end

local function breathe(index)
  -- OpenComputers kills programs that run too long without yielding.
  if os.sleep and index % 2000 == 0 then
    os.sleep(0)
  end
end

local function sizeOf(store)
  assert(
    filesystem.exists(store.path),
    "record was not written: " .. store.path
  )

  return filesystem.size(store.path)
end

-- Ten-digit timestamps, four-decimal fills, thirteen-digit EU/t rates and a
-- permanently draining storage: every persisted field at its widest.
local function fillPowerHistory()
  local store = storage.open(
    "__footprint_power__",
    "history",
    {
      version = 4,
      default = function()
        return {
          buckets = {},
          timeline = {version = 1, tiers = {}},
        }
      end,
    }
  )

  local time = 1000000000

  local model = powerAnalytics.create(
    {id = "footprint", name = "Footprint"},
    {
      settings = {
        sampleSeconds = SAMPLE_SECONDS,
        historyCapacity = 1440,
        liveHistoryCapacity = 180,
      },
      now = function()
        return time
      end,
      history = store:load(),
      persist = function(state)
        return store:trySave(state)
      end,
    }
  )

  local samples = math.floor(HOURS * 3600 / SAMPLE_SECONDS)

  for index = 1, samples do
    time = 1000000000 + index * SAMPLE_SECONDS

    -- Stored energy wobbles so value, minimum and maximum all differ.
    local stored = 123456789012345678 + (index % 997) * 1234567890123

    model:sample(
      {
        stored = tostring(stored),
        capacity = "999999999999999999",
        input = 1234567890123.4 + (index % 7),
        output = 9876543210987.6 + (index % 11),
      },
      time
    )

    breathe(index)
  end

  assert(model:flush(), "power history flush failed: " .. tostring(store.lastError))

  local stats = model:historyStats()

  assert(
    stats.count >= 1440,
    "expected a full day of minute buckets, got " .. tostring(stats.count)
  )

  return sizeOf(store)
end

-- Thirty-two resolved incidents with long names, messages and addresses.
local function fillIncidentHistory()
  local store = storage.open(
    "__footprint_dashboard__",
    "incidents",
    {
      version = 1,
      default = function()
        return {resolved = {}}
      end,
    }
  )

  local dashboard = incidentDashboard.create({history = store})

  local name = string.rep("Very Long Production Line Name ", 2)
  local message = name .. " cannot read its configured ME network."
  local address = "0123abcd-4567-89ef-0123-456789abcdef"

  for index = 1, 40 do
    local packet = {
      source = "production_line",
      id = "line-" .. string.rep("x", 32) .. tostring(index),
      address = address,
      uptime = 1000000000 + index,
      data = {
        id = "ae2-unavailable-" .. tostring(index),
        title = "AE2 connection lost on " .. name,
        message = message,
        raisedAt = 1000000000 + index,
      },
    }

    packet.event = "incident_raised"
    assert(dashboard:handle(packet), "incident was not raised")

    packet.event = "incident_resolved"
    packet.data.resolvedAt = packet.uptime + 1
    assert(dashboard:handle(packet), "incident was not resolved")
  end

  assert(#dashboard:history() == 32, "history should be capped at 32")

  return sizeOf(store)
end

cleanup()

local ok, err = pcall(function()
  local powerBytes = fillPowerHistory()
  local incidentBytes = fillIncidentHistory()

  print(
    string.format(
      "storage footprint: power %d B, incidents %d B",
      powerBytes,
      incidentBytes
    )
  )

  assert(
    powerBytes <= POWER_BUDGET,
    string.format(
      "power history record is %d bytes, budget is %d",
      powerBytes,
      POWER_BUDGET
    )
  )

  assert(
    incidentBytes <= INCIDENT_BUDGET,
    string.format(
      "incident history record is %d bytes, budget is %d",
      incidentBytes,
      INCIDENT_BUDGET
    )
  )
end)

cleanup()

for _, namespace in ipairs(namespaces) do
  assert(
    not filesystem.exists(filesystem.concat(dataRoot, namespace)),
    "footprint test left data behind: " .. namespace
  )
end

if not ok then
  error(err, 0)
end

print("storage footprint: OK")
