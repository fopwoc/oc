local component = require("component")
local computer = require("computer")
local event = require("event")

local host = {}

-- Resolving the bound screen and its keyboards costs several component calls;
-- cache them briefly instead of paying that for every key press and touch.
local LOCAL_INPUT_CACHE_SECONDS = 2

local cache = {
  expiresAt = 0,
  screen = nil,
  keyboards = {},
}

local function refreshLocalInput(now)
  cache.expiresAt = now + LOCAL_INPUT_CACHE_SECONDS
  cache.screen = nil
  cache.keyboards = {}

  local gpuOk, gpu =
      pcall(function()
        return component.gpu
      end)

  if not gpuOk or not gpu then
    return
  end

  local screenOk, screen =
      pcall(gpu.getScreen)

  if not screenOk or not screen then
    return
  end

  cache.screen = screen

  local invokeOk, keyboards =
      pcall(
        component.invoke,
        screen,
        "getKeyboards"
      )

  if invokeOk and type(keyboards) == "table" then
    for _, address in ipairs(keyboards) do
      cache.keyboards[address] = true
    end
  end
end

local function isLocalInput(item)
  local now = computer.uptime()

  if now >= cache.expiresAt then
    refreshLocalInput(now)
  end

  if not cache.screen then
    return false
  end

  if
      item.type == "touch"
      or item.type == "scroll"
      or item.type == "drag"
      or item.type == "drop"
  then
    return item.screen == cache.screen
  end

  if item.type == "keyDown" or item.type == "keyUp" then
    return cache.keyboards[item.keyboard] == true
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
