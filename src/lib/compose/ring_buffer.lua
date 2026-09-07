local ringBuffer = {}

local RingBuffer = {}
RingBuffer.__index = RingBuffer

local function nextIndex(index, limit)
  return index == limit and 1 or index + 1
end

local function assertCapacity(capacity)
  assert(
    type(capacity) == "number"
      and capacity >= 1
      and capacity == math.floor(capacity),
    "RingBuffer capacity must be a positive integer"
  )
end

function RingBuffer:capacity()
  return self.limit
end

function RingBuffer:size()
  return self.count
end

function RingBuffer:isEmpty()
  return self.count == 0
end

function RingBuffer:isFull()
  return self.count == self.limit
end

function RingBuffer:version()
  return self.revision
end

function RingBuffer:get(index)
  if
      type(index) ~= "number"
      or index < 1
      or index > self.count
  then
    return nil
  end

  local offset = index - 1
  local position = self.head + offset

  while position > self.limit do
    position = position - self.limit
  end

  return self.values[position]
end

function RingBuffer:notify()
  for listener in pairs(self.listeners) do
    listener(self)
  end
end

function RingBuffer:push(value)
  assert(
    value ~= nil,
    "RingBuffer cannot store nil"
  )

  local position

  if self.count < self.limit then
    position = self.head + self.count

    while position > self.limit do
      position = position - self.limit
    end

    self.count = self.count + 1
  else
    position = self.head
    self.head = nextIndex(self.head, self.limit)
  end

  self.values[position] = value
  self.revision = self.revision + 1
  self:notify()

  return value
end

function RingBuffer:clear()
  if self.count == 0 then
    return
  end

  for index = 1, self.limit do
    self.values[index] = nil
  end

  self.head = 1
  self.count = 0
  self.revision = self.revision + 1
  self:notify()
end

function RingBuffer:iter()
  local index = 0

  return function()
    index = index + 1

    if index > self.count then
      return nil
    end

    return index, self:get(index)
  end
end

function RingBuffer:subscribe(listener)
  assert(
    type(listener) == "function",
    "RingBuffer listener must be a function"
  )

  self.listeners[listener] = true

  return function()
    self.listeners[listener] = nil
  end
end

function ringBuffer.create(capacity)
  assertCapacity(capacity)

  return setmetatable({
    limit = capacity,
    values = {},
    head = 1,
    count = 0,
    revision = 0,
    listeners = {},
  }, RingBuffer)
end

return ringBuffer
