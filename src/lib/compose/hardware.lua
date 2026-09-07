local component = require("component")
local computer = require("computer")

local hardware = {}

local function call(object, method, ...)
  local ok, value, second, third =
      pcall(object[method], ...)

  if not ok then
    return nil
  end

  return value, second, third
end

local function available(name)
  local value = call(component, "isAvailable", name)
  return value == true
end

local function percent(used, total)
  if not total or total <= 0 then
    return nil
  end

  return math.floor(
    math.max(0, math.min(100, used / total * 100))
    + 0.5
  )
end

local function resolutionTier(width, height)
  if width == nil or height == nil then
    return nil
  end

  if width >= 160 and height >= 50 then
    return 3
  end

  if width >= 80 and height >= 25 then
    return 2
  end

  if width >= 50 and height >= 16 then
    return 1
  end

  return nil
end

function hardware.snapshot(gpu)
  if not gpu then
    local ok, primary =
        pcall(function()
          return component.gpu
        end)

    gpu = ok and primary or nil
  end

  local totalMemory =
      call(computer, "totalMemory")

  local freeMemory =
      call(computer, "freeMemory")

  local usedMemory

  if totalMemory and freeMemory then
    usedMemory =
        math.max(0, totalMemory - freeMemory)
  end

  local snapshot = {
    gpuAvailable = available("gpu"),
    screenAvailable = available("screen"),
    keyboardAvailable = available("keyboard"),
    modemAvailable = available("modem"),
    internetAvailable = available("internet"),

    totalMemory = totalMemory,
    freeMemory = freeMemory,
    usedMemory = usedMemory,
    memoryPercent = percent(
      usedMemory,
      totalMemory
    ),

    screenBound = false,
    width = nil,
    height = nil,
    depth = nil,
    maxDepth = nil,
    maxWidth = nil,
    maxHeight = nil,
    screenTier = nil,
  }

  if not gpu then
    return snapshot
  end

  local screen =
      call(gpu, "getScreen")

  snapshot.screenBound =
      screen ~= nil

  if not screen then
    return snapshot
  end

  snapshot.width,
  snapshot.height =
      call(gpu, "getResolution")

  snapshot.depth =
      call(gpu, "getDepth")

  snapshot.maxDepth =
      call(gpu, "maxDepth")

  snapshot.maxWidth,
  snapshot.maxHeight =
      call(gpu, "maxResolution")

  snapshot.screenTier =
      resolutionTier(
        snapshot.maxWidth,
        snapshot.maxHeight
      )

  return snapshot
end

return hardware
