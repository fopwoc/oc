local input = {}

local MAX_EVENTS = 128

local queue = {}
local head = 1
local tail = 0

local function size()
  return tail - head + 1
end

local function compact()
  if head <= 1 then
    return
  end

  local newQueue = {}
  local newTail = 0

  for i = head, tail do
    newTail = newTail + 1
    newQueue[newTail] = queue[i]
  end

  queue = newQueue
  head = 1
  tail = newTail
end

local function push(event)
  if size() >= MAX_EVENTS then
    queue[head] = nil
    head = head + 1
  end

  tail = tail + 1
  queue[tail] = event

  if head > 64 then
    compact()
  end
end

function input.pushRaw(
    name,
    address,
    a,
    b,
    c,
    d,
    e
)
  if name == "key_down" then
    push({
      type = "keyDown",
      keyboard = address,
      char = a,
      code = b,
      player = c,
    })
  elseif name == "key_up" then
    push({
      type = "keyUp",
      keyboard = address,
      char = a,
      code = b,
      player = c,
    })
  elseif name == "touch" then
    push({
      type = "touch",
      screen = address,
      x = a,
      y = b,
      button = c,
      player = d,
    })
  elseif name == "scroll" then
    push({
      type = "scroll",
      screen = address,
      x = a,
      y = b,
      direction = c,
      player = d,
    })
  elseif name == "drag" then
    push({
      type = "drag",
      screen = address,
      x = a,
      y = b,
      button = c,
      player = d,
    })
  elseif name == "drop" then
    push({
      type = "drop",
      screen = address,
      x = a,
      y = b,
      button = c,
      player = d,
    })
  end
end

function input.poll()
  if head > tail then
    return nil
  end

  local event = queue[head]

  queue[head] = nil
  head = head + 1

  if head > tail then
    queue = {}
    head = 1
    tail = 0
  end

  return event
end

function input.drain()
  local events = {}

  while true do
    local event = input.poll()

    if not event then
      break
    end

    events[#events + 1] = event
  end

  return events
end

function input.size()
  return math.max(0, size())
end

function input.clear()
  queue = {}
  head = 1
  tail = 0
end

return input
