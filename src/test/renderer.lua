local component = require("component")
local nodes = require("lib.compose.nodes")
local renderer = require("lib.compose.renderer")

assert(
  component.isAvailable("gpu"),
  "renderer test requires a GPU"
)

local gpu = component.gpu

renderer.reset({gpu = gpu})

local measured = renderer.render(
  nodes.Text("hello"),
  {gpu = gpu}
)

assert(measured.width == 5)
assert(measured.height == 1)

renderer.reset({gpu = gpu})

print("renderer: OK")
