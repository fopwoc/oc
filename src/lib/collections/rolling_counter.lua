local ringBuffer = require("lib.compose.ring_buffer")

local rollingCounter = {}

local DEFAULT_WINDOW_SECONDS = 60 * 60
local DEFAULT_CAPACITY = 1024

function rollingCounter.create(options)
  options = options or {}

  local windowSeconds =
      options.windowSeconds
      or DEFAULT_WINDOW_SECONDS
  local buffer = ringBuffer.create(
    options.capacity
      or DEFAULT_CAPACITY
  )

  assert(
    type(windowSeconds) == "number"
      and windowSeconds > 0,
    "Rolling counter window must be positive"
  )

  local instance = {}

  function instance:record(time)
    assert(
      type(time) == "number",
      "Recorded time must be numeric"
    )

    buffer:push(time)
  end

  function instance:count(time)
    local cutoff = time - windowSeconds
    local count = 0

    for _, completedAt in buffer:iter() do
      if completedAt >= cutoff then
        count = count + 1
      end
    end

    return count
  end

  function instance:perHour(time)
    return self:count(time)
        * (60 * 60)
        / windowSeconds
  end

  function instance:size()
    return buffer:size()
  end

  return instance
end

return rollingCounter
