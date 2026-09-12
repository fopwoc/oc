local coroutines = {}

function coroutines.delay(seconds)
  assert(
    type(seconds) == "number"
      and seconds >= 0,
    "coroutines.delay requires a non-negative number"
  )

  return coroutine.yield({
    kind = "delay",
    seconds = seconds,
  })
end

function coroutines.awaitEvent(name)
  assert(
    type(name) == "string"
      and name ~= "",
    "coroutines.awaitEvent requires a non-empty event name"
  )

  return coroutine.yield({
    kind = "event",
    name = name,
  })
end

function coroutines.create(options)
  options = options or {}

  assert(
    type(options.now) == "function",
    "coroutine scheduler requires now()"
  )

  local instance = {
    now = options.now,
    effects = {},
  }

  local function resume(effect, ...)
    effect.waitingEvent = nil

    local ok, yielded =
        coroutine.resume(
          effect.thread,
          ...
        )

    if not ok then
      -- The coroutine stack is still intact here; capture it before the
      -- error leaves the scheduler or the failing line is lost.
      error(debug.traceback(effect.thread, tostring(yielded)), 0)
    end

    if coroutine.status(effect.thread) == "dead" then
      return
    end

    if
        type(yielded) == "table"
        and yielded.kind == "delay"
    then
      effect.wakeAt =
          instance.now()
          + yielded.seconds
    elseif
        type(yielded) == "table"
        and yielded.kind == "event"
    then
      effect.wakeAt = nil
      effect.waitingEvent = yielded.name
    else
      effect.wakeAt = instance.now()
    end
  end

  function instance:launch(block, optionsValue)
    assert(
      type(block) == "function",
      "coroutine scheduler requires a function"
    )

    optionsValue = optionsValue or {}

    local effect = {
      kind = "coroutine",
      thread = coroutine.create(block),
      wakeAt = optionsValue.wakeAt or 0,
      waitingEvent = nil,
      isActive = optionsValue.isActive,
      cancelled = false,
    }

    self.effects[#self.effects + 1] = effect

    return effect
  end

  function instance:cancel(effect)
    if effect then
      effect.cancelled = true
    end
  end

  function instance:run()
    local currentTime = self.now()
    local index = 1

    while index <= #self.effects do
      local effect = self.effects[index]
      local active =
          not effect.isActive
          or effect.isActive()

      if
          effect.cancelled
          or coroutine.status(effect.thread) == "dead"
      then
        table.remove(self.effects, index)
      elseif
          active
          and not effect.waitingEvent
          and effect.wakeAt <= currentTime
      then
        resume(effect)

        if coroutine.status(effect.thread) == "dead" then
          table.remove(self.effects, index)
        else
          index = index + 1
        end
      else
        index = index + 1
      end
    end
  end

  function instance:dispatch(name, ...)
    for _, effect in ipairs(self.effects) do
      local active =
          not effect.isActive
          or effect.isActive()

      if
          not effect.cancelled
          and active
          and effect.waitingEvent == name
          and coroutine.status(effect.thread) ~= "dead"
      then
        resume(effect, name, ...)
      end
    end
  end

  function instance:nextWake()
    local wakeAt = nil

    for _, effect in ipairs(self.effects) do
      local active =
          not effect.isActive
          or effect.isActive()

      if
          not effect.cancelled
          and active
          and not effect.waitingEvent
          and coroutine.status(effect.thread) ~= "dead"
      then
        if wakeAt == nil or effect.wakeAt < wakeAt then
          wakeAt = effect.wakeAt
        end
      end
    end

    if not wakeAt then
      return 1
    end

    return math.max(0, wakeAt - self.now())
  end

  function instance:dispose()
    for _, effect in ipairs(self.effects) do
      effect.cancelled = true
    end

    self.effects = {}
  end

  return instance
end

return coroutines
