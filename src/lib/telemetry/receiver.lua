local component =
    require("component")

local protocol =
    require("lib.telemetry.protocol")

local receiver = {}

local modem =
    component.modem


function receiver.create(options)
  options = options or {}

  local instance = {
    port =
        options.port
        or protocol.DEFAULT_PORT,
  }


  function instance:open()
    return modem.open(
      self.port
    )
  end

  function instance:close()
    return modem.close(
      self.port
    )
  end

  function instance:receive(
      eventName,
      localAddress,
      from,
      port,
      distance,
      payload
  )
    if eventName ~= "modem_message" then
      return nil
    end

    if port ~= self.port then
      return nil
    end

    local packet =
        protocol.decode(
          payload
        )

    if not packet then
      return nil
    end

    return {
      source = packet.source,
      id = packet.id,
      uptime = packet.uptime,
      data = packet.data,
      event = packet.event,

      localAddress =
          localAddress,

      address =
          from,

      distance =
          distance,
    }
  end

  return instance
end

return receiver
