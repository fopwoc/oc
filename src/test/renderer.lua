local component = require("component")
local framebuffer = require("lib.compose.framebuffer")
local nodes = require("lib.compose.nodes")
local modifier = require("lib.compose.modifier")
local renderer = require("lib.compose.renderer")
local scroll = require("lib.compose.scroll")

assert(
  component.isAvailable("gpu"),
  "renderer test requires a GPU"
)

local gpu = component.gpu
local rendererOptions = {
  gpu = gpu,
  clear = false,
}

local shiftedFrame = framebuffer.create(1, 4)

for row = 1, 4 do
  framebuffer.set(
    shiftedFrame,
    1,
    row,
    tostring(row)
  )
end

framebuffer.shift(
  shiftedFrame,
  1,
  1,
  1,
  4,
  1
)

assert(shiftedFrame.chars[1] == "2")
assert(shiftedFrame.chars[2] == "3")
assert(shiftedFrame.chars[3] == "4")
assert(shiftedFrame.chars[4] == false)

renderer.reset(rendererOptions)

local measured = renderer.render(
  nodes.Text("hello"),
  rendererOptions
)

assert(measured.width == 5)
assert(measured.height == 1)

local scrollState = scroll.createState(function()
end)

scrollState:setMaxValue(3)

local scrollChildren = {}

for index = 1, 8 do
  scrollChildren[#scrollChildren + 1] =
      nodes.Text("row " .. tostring(index))
end

local scrollTree =
    nodes.Column(
      scrollChildren,
      modifier.Modifier
      :width(20)
      :height(5)
      :verticalScroll(scrollState)
    )

renderer.render(
  scrollTree,
  rendererOptions
)

scrollState:scrollTo(1)

renderer.render(
  scrollTree,
  rendererOptions
)

assert(
  renderer.metrics().scrollBlit,
  "renderer did not use GPU scroll blit"
)

renderer.reset(rendererOptions)

print("renderer: OK")
