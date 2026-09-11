local ringBuffer = require("lib.collections.ring_buffer")

local buffer = ringBuffer.create(3)

assert(buffer:capacity() == 3)
assert(buffer:size() == 0)
assert(buffer:isEmpty())

buffer:push("one")
buffer:push("two")
buffer:push("three")

assert(buffer:size() == 3)
assert(buffer:isFull())
assert(buffer:get(1) == "one")
assert(buffer:get(3) == "three")

buffer:push("four")

assert(buffer:size() == 3)
assert(buffer:get(1) == "two")
assert(buffer:get(2) == "three")
assert(buffer:get(3) == "four")
assert(buffer:get(4) == nil)

local values = {}

for index, value in buffer:iter() do
  values[index] = value
end

assert(values[1] == "two")
assert(values[2] == "three")
assert(values[3] == "four")

local notifications = 0
local unsubscribe =
    buffer:subscribe(function()
      notifications = notifications + 1
    end)

buffer:push("five")
assert(notifications == 1)

unsubscribe()
buffer:push("six")
assert(notifications == 1)

buffer:clear()
assert(buffer:isEmpty())
assert(buffer:size() == 0)
assert(notifications == 1)

print("ring buffer: OK")
