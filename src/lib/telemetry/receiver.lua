local component =
    require("component")

local protocol =
    require("lib.telemetry.protocol")

local receiver = {}

-- OpenOS raises instead of returning nil when no primary modem exists.
local function resolveModem()
  local ok, modem =
      pcall(function()
        return component.modem
      end)

  if not ok or not modem then
    return nil, "telemetry modem is unavailable"
  end

  return modem
end


function receiver.create(options)
  options = options or {}

  local instance = {
    port =
        options.port
        or protocol.DEFAULT_PORT,
  }


  function instance:open()
    local modem, errorMessage = resolveModem()

    if not modem then
      return nil, errorMessage
    end

    local checked, alreadyOpen = pcall(
      modem.isOpen,
      self.port
    )

    if checked and alreadyOpen == true then
      self.modem = modem
      self.ownsPort = false
      return true
    end

    local ok, opened, openError = pcall(
      modem.open,
      self.port
    )

    if not ok then
      return nil, opened
    end

    if opened ~= true then
      local rechecked, nowOpen = pcall(
        modem.isOpen,
        self.port
      )

      if rechecked and nowOpen == true then
        self.modem = modem
        self.ownsPort = false
        return true
      end

      return nil,
        openError
        or "modem open returned " .. tostring(opened)
    end

    self.modem = modem
    self.ownsPort = true
    return true
  end

  function instance:close()
    local modem = self.modem

    if not modem then
      return false
    end

    self.modem = nil

    if not self.ownsPort then
      return true
    end

    self.ownsPort = nil
    return modem.close(self.port)
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
