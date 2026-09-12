for _, path in ipairs({
  "src/test/compose/engine.lua",
  "src/test/compose/color.lua",
  "src/test/compose/color_math.lua",
  "test/compose/color_style.lua",
  "src/test/compose/framebuffer.lua",
  "src/test/compose/ring_buffer.lua",
  "test/compose/scroll.lua",
  "src/test/compose/navigation_engine.lua",
  "src/test/compose/lifecycle.lua",
}) do
  dofile(path)
end

print("compose tests: OK")
