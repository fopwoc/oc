local store = {}

local function clock()
  return require("computer").uptime()
end

local function keyFor(packet)
  local key =
      packet.source .. ":" .. packet.id

  if packet.address then
    key = key .. ":" .. tostring(packet.address)
  end

  return key
end

function store.create(options)
  options = options or {}

  local now = options.clock or clock
  local instance = {
    sources = {},
  }

  function instance:update(packet)
    assert(
      type(packet) == "table",
      "Telemetry packet must be a table"
    )

    local key = keyFor(packet)

    local source = self.sources[key]

    if not source then
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
    end

    source.address = packet.address
    source.distance = packet.distance
    source.lastSeen = now()
    source.remoteUptime = packet.uptime
    source.data = packet.data

    return source
  end

  function instance:get(source, id)
    local prefix = source .. ":" .. id

    for key, value in pairs(self.sources) do
      if key == prefix
          or key:sub(1, #prefix + 1)
              == prefix .. ":"
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

  function instance:age(source)
    return now() - source.lastSeen
  end

  return instance
end

return store
