for _, path in ipairs({
  "test/compose/engine.lua",
  "test/compose/color.lua",
  "test/compose/ring_buffer.lua",
  "test/compose/navigation_engine.lua",
  "test/compose/lifecycle.lua",
  "test/compose/renderer.lua",
}) do
  dofile(path)
end

print("compose test suite: OK")
