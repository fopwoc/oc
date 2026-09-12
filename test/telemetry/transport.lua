package.path = "src/?.lua;" .. package.path

local previous = {
  component = package.loaded.component,
  computer = package.loaded.computer,
  protocol = package.loaded["lib.telemetry.protocol"],
  receiver = package.loaded["lib.telemetry.receiver"],
  sender = package.loaded["lib.telemetry.sender"],
}

local activeModem
local broadcastResult = true
local broadcastError

package.loaded.component = setmetatable({}, {
  __index = function(_, key)
    if key == "modem" then
      -- Mirror OpenOS: a missing primary component raises.
      assert(activeModem, "no primary 'modem' available")
      return activeModem
    end
  end,
})

package.loaded.computer = {
  uptime = function()
    return 10
  end,
}

package.loaded["lib.telemetry.protocol"] = {
  DEFAULT_PORT = 4242,
  encode = function()
    return "encoded"
  end,
  decode = function(payload)
    if payload == "encoded" then
      return {
        source = "source",
        id = "id",
        uptime = 10,
        data = {},
        event = "telemetry",
      }
    end
  end,
}

activeModem = {
  broadcast = function()
    return broadcastResult, broadcastError
  end,
  open = function()
    return true
  end,
  isOpen = function()
    return false
  end,
  close = function()
    return true
  end,
}

package.loaded["lib.telemetry.sender"] = nil
package.loaded["lib.telemetry.receiver"] = nil

local senderModule = require("lib.telemetry.sender")
local receiverModule = require("lib.telemetry.receiver")
local sender = senderModule.create({source = "source", id = "id"})

broadcastResult = nil
broadcastError = "wireless card rejected packet"

local sent, sendError = sender:send({})

assert(
  sent == nil
    and sendError == broadcastError
    and sender:status().state == "failed",
  "sender should report non-throwing modem failures"
)

activeModem = nil
local missing, missingError = sender:send({})

assert(
  missing == nil
    and missingError == "telemetry modem is unavailable",
  "sender should report a missing modem"
)

activeModem = {
  broadcast = function()
    return true
  end,
  open = function()
    return true
  end,
  isOpen = function()
    return false
  end,
  close = function()
    return true
  end,
}

assert(
  sender:send({}) == true
    and sender:status().state == "sent",
  "sender should recover after a modem becomes available"
)

activeModem = nil
local receiver = receiverModule.create()
local opened, openError = receiver:open()

assert(
  opened == nil
    and openError == "telemetry modem is unavailable",
  "receiver should report a missing modem"
)

activeModem = {
  open = function()
    return nil, "port unavailable"
  end,
  isOpen = function()
    return false
  end,
}

opened, openError = receiver:open()

assert(
  opened == nil and openError == "port unavailable",
  "receiver should report non-throwing open failures"
)

local closedExisting = false

activeModem = {
  isOpen = function()
    return true
  end,
  open = function()
    error("already-open ports should not be opened again")
  end,
  close = function()
    closedExisting = true
  end,
}

assert(
  receiver:open() == true and receiver:close() == true
    and not closedExisting,
  "receiver should reuse but not close an already-open port"
)

package.loaded.component = previous.component
package.loaded.computer = previous.computer
package.loaded["lib.telemetry.protocol"] = previous.protocol
package.loaded["lib.telemetry.receiver"] = previous.receiver
package.loaded["lib.telemetry.sender"] = previous.sender

print("telemetry transport: OK")
