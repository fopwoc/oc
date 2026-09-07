local component =
  require("component")

local computer =
  require("computer")

local protocol =
  require("../lib/telemetry/protocol")

local sender = {}

local modem =
  component.modem


function sender.create(options)
  options =
    options or {}

  local source =
    assert(
      options.source,
      "Telemetry source is required"
    )

  local id =
    assert(
      options.id,
      "Telemetry id is required"
    )

  local port =
    options.port
      or protocol.DEFAULT_PORT

  local instance = {}


  function instance:send(data)
    local payload =
      protocol.encode(
        source,
        id,
        computer.uptime(),
        data
      )

    return modem.broadcast(
      port,
      payload
    )
  end


  return instance
end


return sender
