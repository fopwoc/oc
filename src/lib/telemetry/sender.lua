local component =
    require("component")

local computer =
    require("computer")

local protocol =
    require("lib.telemetry.protocol")

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

  instance.source = source
  instance.id = id
  instance.port = port
  instance._status = {
    state = "waiting",
    uptime = nil,
    error = nil,
  }

  local function setStatus(state, errorMessage)
    instance._status.state = state
    instance._status.uptime = computer.uptime()
    instance._status.error = errorMessage
  end

  function instance:sendEvent(event, data)
    local encoded, payload =
        pcall(
          protocol.encode,
          source,
          id,
          computer.uptime(),
          data,
          event
        )

    if not encoded then
      setStatus("failed", tostring(payload))
      return nil, payload
    end

    local sent, result =
        pcall(function()
          return modem.broadcast(
            port,
            payload
          )
        end)

    if not sent then
      setStatus("failed", tostring(result))
      return nil, result
    end

    if result == false then
      local errorMessage =
          "modem broadcast returned false"

      setStatus("failed", errorMessage)
      return result, errorMessage
    end

    setStatus("sent")

    return result
  end

  function instance:send(data)
    return self:sendEvent(nil, data)
  end

  function instance:status()
    return {
      state = self._status.state,
      uptime = self._status.uptime,
      error = self._status.error,
    }
  end

  return instance
end

return sender
