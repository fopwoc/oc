local component = require("component")
local computer = require("computer")
local event = require("event")

local host = {}

local function isLocalInput(item)
  local gpu = component.gpu
  local screen = gpu.getScreen()

  if not screen then
    return false
  end

  if
      item.type == "touch"
      or item.type == "scroll"
      or item.type == "drag"
      or item.type == "drop"
  then
    return item.screen == screen
  end

  if item.type == "keyDown" or item.type == "keyUp" then
    local keyboards = component.invoke(
      screen,
      "getKeyboards"
    )

    for _, address in ipairs(keyboards) do
      if item.keyboard == address then
        return true
      end
    end

    return false
  end

  return true
end

function host.create()
  return {
    now = computer.uptime,

    pull = function(timeout)
      return {event.pull(timeout)}
    end,

    isLocalInput = isLocalInput,
  }
end

return host
