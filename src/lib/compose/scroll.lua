local scroll = {}

local ScrollState = {}
ScrollState.__index = ScrollState

function ScrollState:new(invalidate)
  return setmetatable({
    value = 0,
    maxValue = 0,
    invalidate = invalidate,
  }, self)
end

function ScrollState:getValue()
  return self.value
end

function ScrollState:scrollBy(delta)
  return self:scrollTo(
    self.value + delta
  )
end

function ScrollState:scrollTo(value)
  local newValue =
      math.max(
        0,
        math.min(
          self.maxValue,
          value
        )
      )

  if newValue == self.value then
    return self.value
  end

  self.value = newValue

  if self.invalidate then
    self.invalidate()
  end

  return self.value
end

function ScrollState:setMaxValue(value)
  local maxValue =
      math.max(
        0,
        value or 0
      )

  self.maxValue = maxValue

  if self.value > maxValue then
    self.value = maxValue
  end
end

function scroll.createState(invalidate)
  assert(
    type(invalidate) == "function",
    "ScrollState requires invalidate callback"
  )

  return ScrollState:new(invalidate)
end

return scroll
