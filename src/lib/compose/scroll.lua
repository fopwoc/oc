local scroll = {}

local ScrollState = {}
ScrollState.__index = ScrollState

function ScrollState:new(invalidate)
  return setmetatable({
    value = 0,
    maxValue = 0,
    followingEnd = false,
    invalidate = invalidate,
  }, self)
end

function ScrollState:getValue()
  return self.value
end

function ScrollState:scrollBy(delta)
  self.followingEnd = false

  return self:scrollTo(
    self.value + delta
  )
end

function ScrollState:isAtEnd()
  return self.value >= self.maxValue
end

function ScrollState:followEnd()
  self.followingEnd = true

  return self:scrollTo(self.maxValue)
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

  if self.followingEnd then
    self.value = maxValue
  end

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
