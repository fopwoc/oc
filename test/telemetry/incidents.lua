package.path = "src/?.lua;" .. package.path

local incidentManager =
    require("lib.telemetry.incidents.manager")

local now = 10
local events = {}

local incidents = incidentManager.create({
  clock = function()
    return now
  end,
  send = function(event, data)
    events[#events + 1] = {
      event = event,
      data = data,
    }
  end,
})

local first, created = incidents:raise({
  id = "power-loss",
  title = "Power lost",
  message = "Storage is depleted",
})

assert(
  created
    and first.raisedAt == 10
    and #events == 1
    and events[1].event == "incident_raised",
  "new incident should be raised and transmitted"
)

now = 20

local duplicate, duplicateCreated = incidents:raise({
  id = "power-loss",
  title = "Power lost again",
  message = "Updated message",
})

assert(
  duplicate == first
    and not duplicateCreated
    and #events == 1,
  "active incident raises should be deduplicated"
)

local missing = incidents:resolve("missing")

assert(
  missing == nil
    and #events == 1,
  "resolving a missing incident should be a no-op"
)

local resolved, didResolve = incidents:resolve("power-loss")

assert(
  didResolve
    and resolved.resolvedAt == 20
    and #incidents:activeList() == 0
    and #events == 2
    and events[2].event == "incident_resolved",
  "active incident should resolve and transmit once"
)

now = 30
incidents:raise({
  id = "connection-lost",
  title = "Connection lost",
  message = "Reconnect the controller",
})

incidents:sync()

assert(
  #events == 4
    and events[4].event == "incident_snapshot"
    and #events[4].data.active == 1,
  "sync should send active incidents as a snapshot"
)

local safe = incidentManager.create({
  clock = function()
    return 1
  end,
  send = function()
    error("modem unavailable")
  end,
})

local safeIncident = safe:raise({
  id = "transport-failure",
  title = "Transport failure",
  message = "The application must continue",
})

assert(
  safeIncident
    and #safe:activeList() == 1,
  "transport failures must not prevent local incident state"
)

print("incidents: OK")
