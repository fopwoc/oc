local computer =
    require("computer")

local state = {}


function state.create()
  local instance = {
    sources = {},
  }


  function instance:update(packet)
    assert(
      type(packet) == "table",
      "Telemetry packet must be a table"
    )

    local key =
        packet.source
        .. ":"
        .. packet.id

    local source =
        self.sources[key]

    if not source then
      source = {
        source =
            packet.source,

        id =
            packet.id,

        address =
            packet.address,

        distance =
            packet.distance,

        firstSeen =
            computer.uptime(),

        lastSeen =
            0,

        remoteUptime =
            0,

        data = {},
      }

      self.sources[key] =
          source
    end


    source.address =
        packet.address

    source.distance =
        packet.distance

    source.lastSeen =
        computer.uptime()

    source.remoteUptime =
        packet.uptime

    source.data =
        packet.data


    return source
  end

  function instance:get(
      source,
      id
  )
    return self.sources[
    source
    .. ":"
    .. id
    ]
  end

  function instance:all()
    local result = {}

    for _, source in pairs(
      self.sources
    ) do
      result[#result + 1] =
          source
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
    return computer.uptime()
        - source.lastSeen
  end

  return instance
end

return state
