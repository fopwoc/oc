local dashboard = {}

local HISTORY_LIMIT = 32

local function keyFor(source, sourceId, incidentId)
  return source
    .. ":"
    .. sourceId
    .. ":"
    .. incidentId
end

local function copyIncident(value)
  return {
    key = value.key,
    source = value.source,
    sourceId = value.sourceId,
    id = value.id,
    title = value.title,
    message = value.message,
    raisedAt = value.raisedAt,
    resolvedAt = value.resolvedAt,
  }
end

local function validIncident(value)
  return type(value) == "table"
    and type(value.id) == "string"
    and value.id ~= ""
    and type(value.title) == "string"
    and type(value.message) == "string"
    and type(value.raisedAt) == "number"
end

local function normalize(packet, value)
  if not validIncident(value) then
    return nil
  end

  local source = packet.source
  local sourceId = packet.id

  if type(source) ~= "string"
      or type(sourceId) ~= "string"
  then
    return nil
  end

  return {
    key = keyFor(source, sourceId, value.id),
    source = source,
    sourceId = sourceId,
    id = value.id,
    title = value.title,
    message = value.message,
    raisedAt = value.raisedAt,
    resolvedAt = value.resolvedAt,
  }
end

function dashboard.create(options)
  options = options or {}

  local historyStore =
      assert(
        options.history,
        "Telemetry incident dashboard requires a history store"
      )

  assert(
    type(historyStore.load) == "function"
      and type(historyStore.save) == "function",
    "Telemetry incident history requires load and save functions"
  )

  local persisted = historyStore:load()

  if type(persisted) ~= "table"
      or type(persisted.resolved) ~= "table"
  then
    persisted = {
      resolved = {},
    }

    pcall(
      historyStore.save,
      historyStore,
      persisted
    )
  end

  local historyTrimmed = false

  while #persisted.resolved > HISTORY_LIMIT do
    table.remove(persisted.resolved)
    historyTrimmed = true
  end

  if historyTrimmed then
    pcall(
      historyStore.save,
      historyStore,
      persisted
    )
  end

  local instance = {
    active = {},
    queue = {},
    historyStore = historyStore,
    historyItems = persisted.resolved,
    logger = options.logger,
  }

  local function removeFromQueue(key)
    for index = #instance.queue, 1, -1 do
      if instance.queue[index] == key then
        table.remove(instance.queue, index)
      end
    end
  end

  local function persistHistory()
    local ok, err = pcall(
      instance.historyStore.save,
      instance.historyStore,
      {
        resolved = instance.historyItems,
      }
    )

    if not ok and instance.logger then
      pcall(
        instance.logger,
        "failed to persist incident history: " .. tostring(err)
      )
    end
  end

  local function addHistory(incident)
    table.insert(
      instance.historyItems,
      1,
      copyIncident(incident)
    )

    while #instance.historyItems > HISTORY_LIMIT do
      table.remove(instance.historyItems)
    end

    persistHistory()
  end

  function instance:raise(packet)
    local incident = normalize(packet, packet.data)

    if not incident then
      return false
    end

    if self.active[incident.key] then
      return false
    end

    self.active[incident.key] = incident
    self.queue[#self.queue + 1] = incident.key

    return true
  end

  function instance:resolve(packet)
    local value = packet.data or {}
    local source = packet.source
    local sourceId = packet.id
    local incidentId = value.id

    if type(source) ~= "string"
        or type(sourceId) ~= "string"
        or type(incidentId) ~= "string"
    then
      return false
    end

    local key = keyFor(source, sourceId, incidentId)
    local incident = self.active[key]

    if not incident then
      return false
    end

    incident.resolvedAt =
        value.resolvedAt
        or packet.uptime
        or incident.raisedAt

    self.active[key] = nil
    removeFromQueue(key)
    addHistory(incident)

    return true
  end

  function instance:snapshot(packet)
    local value = packet.data or {}
    local changed = false
    local seen = {}

    local activeItems = type(value.active) == "table" and value.active or {}

    for _, item in ipairs(activeItems) do
      local raised = normalize(packet, item)

      if raised then
        seen[raised.key] = true

        if not self.active[raised.key] then
          self.active[raised.key] = raised
          self.queue[#self.queue + 1] = raised.key
          changed = true
        end
      end
    end

    for key, incident in pairs(self.active) do
      if incident.source == packet.source
          and incident.sourceId == packet.id
          and not seen[key]
      then
        incident.resolvedAt =
            packet.uptime
            or incident.raisedAt

        self.active[key] = nil
        removeFromQueue(key)
        addHistory(incident)
        changed = true
      end
    end

    return changed
  end

  function instance:handle(packet)
    if type(packet) ~= "table" then
      return false
    end

    if packet.event == "incident_raised" then
      return self:raise(packet)
    end

    if packet.event == "incident_resolved" then
      return self:resolve(packet)
    end

    if packet.event == "incident_snapshot" then
      return self:snapshot(packet)
    end

    return false
  end

  function instance:current()
    while self.queue[1] do
      local key = self.queue[1]
      local incident = self.active[key]

      if incident then
        return incident
      end

      table.remove(self.queue, 1)
    end

    return nil
  end

  function instance:dismiss(key)
    if self.queue[1] ~= key then
      return false
    end

    table.remove(self.queue, 1)
    return true
  end

  function instance:activeList()
    local result = {}

    for _, incident in pairs(self.active) do
      result[#result + 1] = copyIncident(incident)
    end

    table.sort(
      result,
      function(a, b)
        return a.raisedAt < b.raisedAt
      end
    )

    return result
  end

  function instance:history()
    local result = {}

    for _, incident in ipairs(self.historyItems) do
      result[#result + 1] = copyIncident(incident)
    end

    return result
  end

  function instance:activeCount()
    local count = 0

    for _ in pairs(self.active) do
      count = count + 1
    end

    return count
  end

  return instance
end

return dashboard
