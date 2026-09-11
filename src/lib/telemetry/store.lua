local store = {}
local DEFAULT_CAPACITY = 128

local function keyPart(value)
  value = tostring(value or "")
  return tostring(#value) .. ":" .. value
end

local function clock()
  return require("computer").uptime()
end

local function keyFor(packet)
  return keyPart(packet.source)
    .. keyPart(packet.id)
    .. keyPart(packet.address)
end

function store.create(options)
  options = options or {}

  local now = options.clock or clock
  local capacity = options.capacity or DEFAULT_CAPACITY

  assert(
    type(capacity) == "number"
      and capacity >= 1
      and capacity == math.floor(capacity),
    "Telemetry store capacity must be a positive integer"
  )

  local instance = {
    sources = {},
    count = 0,
    capacity = capacity,
  }

  local function evictOldest()
    local oldestKey
    local oldest

    for key, source in pairs(instance.sources) do
      if not oldest or source.lastSeen < oldest.lastSeen then
        oldestKey = key
        oldest = source
      end
    end

    if oldestKey then
      instance.sources[oldestKey] = nil
      instance.count = instance.count - 1
    end
  end

  function instance:update(packet)
    assert(
      type(packet) == "table",
      "Telemetry packet must be a table"
    )

    local key = keyFor(packet)

    local source = self.sources[key]

    if not source then
      if self.count >= self.capacity then
        evictOldest()
      end

      source = {
        source = packet.source,
        id = packet.id,
        address = packet.address,
        distance = packet.distance,
        firstSeen = now(),
        lastSeen = 0,
        remoteUptime = 0,
        data = {},
      }

      self.sources[key] = source
      self.count = self.count + 1
    end

    source.address = packet.address
    source.distance = packet.distance
    source.lastSeen = now()
    source.remoteUptime = packet.uptime
    source.data = packet.data

    return source
  end

  function instance:get(source, id)
    for _, value in pairs(self.sources) do
      if value.source == source
          and value.id == id
      then
        return value
      end
    end

    return nil
  end

  function instance:all()
    local result = {}

    for _, source in pairs(self.sources) do
      result[#result + 1] = source
    end

    table.sort(
      result,
      function(a, b)
        if a.source == b.source then
          return a.id < b.id
        end

        return a.source < b.source
      end
    )

    return result
  end

  function instance:size()
    return self.count
  end

  function instance:age(source)
    return now() - source.lastSeen
  end

  return instance
end

return store
