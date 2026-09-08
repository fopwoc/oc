for _, path in ipairs({
  "test/compose/engine.lua",
  "test/compose/color.lua",
  "test/compose/color_style.lua",
  "src/test/compose/ring_buffer.lua",
  "test/compose/scroll.lua",
  "test/compose/navigation_engine.lua",
  "test/compose/lifecycle.lua",
}) do
  dofile(path)
end

print("compose tests: OK")
