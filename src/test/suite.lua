local tests = {
  "test/engine.lua",
  "test/color.lua",
  "test/ring_buffer.lua",
  "test/navigation_engine.lua",
  "test/lifecycle.lua",
  "test/renderer.lua",
  "test/scaffold.lua",
}

for _, path in ipairs(tests) do
  dofile(path)
end

print("test suite: OK")
