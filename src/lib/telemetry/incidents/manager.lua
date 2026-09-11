local incidents = {}

local function clock()
  return require("computer").uptime()
end

local function validateIncident(value)
  assert(
    type(value) == "table",
    "Incident must be a table"
  )

  assert(
    type(value.id) == "string"
      and value.id ~= "",
    "Incident id is required"
  )

  assert(
    type(value.title) == "string"
      and value.title ~= "",
    "Incident title is required"
  )

  assert(
    type(value.message) == "string"
      and value.message ~= "",
    "Incident message is required"
  )
end

local function copyIncident(value)
  return {
    id = value.id,
    title = value.title,
    message = value.message,
    raisedAt = value.raisedAt,
    resolvedAt = value.resolvedAt,
  }
end

local function report(instance, message)
  if instance.logger then
    pcall(instance.logger, message)
  end
end

function incidents.create(options)
  options = options or {}

  local send = options.send

  if not send then
    local sender = options.sender

    if not sender then
      local telemetry = require("lib.telemetry.sender")
      sender = telemetry.create(options)
    end

    send = function(event, data)
      return sender:sendEvent(event, data)
    end
  end

  assert(
    type(send) == "function",
    "Incident manager requires a transport"
  )

  local instance = {
    active = {},
    clock = options.clock or clock,
    send = send,
    logger = options.logger,
  }

  local function transmit(event, data)
    local ok, result, errorMessage =
        pcall(instance.send, event, data)

    if not ok then
      report(
        instance,
        "failed to send " .. event .. ": " .. tostring(result)
      )
      return false, result
    end

    if result == false
        or (result == nil and errorMessage ~= nil)
    then
      report(
        instance,
        "failed to send " .. event .. ": " .. tostring(errorMessage)
      )
      return false, errorMessage
    end

    return true, result
  end

  function instance:raise(value)
    validateIncident(value)

    local current = self.active[value.id]

    if current then
      return current, false
    end

    local incident = {
      id = value.id,
      title = value.title,
      message = value.message,
      raisedAt = value.raisedAt or self.clock(),
      resolvedAt = nil,
    }

    self.active[incident.id] = incident
    transmit("incident_raised", copyIncident(incident))

    return incident, true
  end

  function instance:resolve(id, resolvedAt)
    assert(
      type(id) == "string"
        and id ~= "",
      "Incident id is required"
    )

    local incident = self.active[id]

    if not incident then
      return nil, false
    end

    incident.resolvedAt =
        resolvedAt or self.clock()
    self.active[id] = nil

    transmit(
      "incident_resolved",
      copyIncident(incident)
    )

    return incident, true
  end

  function instance:activeList()
    local result = {}

    for _, incident in pairs(self.active) do
      result[#result + 1] = copyIncident(incident)
    end

    table.sort(
      result,
      function(a, b)
        return a.id < b.id
      end
    )

    return result
  end

  function instance:sync()
    return transmit(
      "incident_snapshot",
      {
        active = self:activeList(),
      }
    )
  end

  return instance
end

return incidents
