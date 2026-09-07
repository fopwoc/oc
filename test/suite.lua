for _, path in ipairs({
  "test/engine.lua",
  "test/color.lua",
  "src/test/ring_buffer.lua",
  "test/scroll.lua",
  "test/navigation_engine.lua",
  "test/lifecycle.lua",
}) do
  dofile(path)
end

print("repository test suite: OK")
