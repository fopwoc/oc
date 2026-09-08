package.path = "src/?.lua;" .. package.path

local scroll = require("lib.compose.scroll")

local state = scroll.createState(function()
end)

state:setMaxValue(10)
state:followEnd()

assert(state:getValue() == 10)
assert(state:isAtEnd())

state:scrollBy(-2)
assert(state:getValue() == 8)
assert(not state:isAtEnd())

state:setMaxValue(12)
assert(state:getValue() == 8)

state:followEnd()
assert(state:getValue() == 12)

print("scroll state: OK")
