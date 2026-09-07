local component = require("component")
local computer = require("computer")
local event = require("event")

local host = {}

local function isLocalInput(item)
  local ok, gpu =
      pcall(function()
        return component.gpu
      end)

  if not ok or not gpu then
    return false
  end

  local ok, screen =
      pcall(gpu.getScreen)

  if not ok or not screen then
    return false
  end

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
    local invokeOk, keyboards =
        pcall(
          component.invoke,
          screen,
          "getKeyboards"
        )

    if not invokeOk or type(keyboards) ~= "table" then
      return false
    end

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
