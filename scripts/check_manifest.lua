local SOURCE_ROOT = "src"

local function fail(message)
  error(message, 0)
end

local function assertType(value, expected, message)
  if type(value) ~= expected then
    fail(message .. " (expected " .. expected .. ")")
  end
end

local function validateRelativePath(path, owner)
  assertType(path, "string", owner .. " path must be a string")

  if path == "" or path:sub(1, 1) == "/" or path:find("\\", 1, true) then
    fail(owner .. " path is not relative: " .. tostring(path))
  end

  for segment in path:gmatch("[^/]+") do
    if segment == "." or segment == ".." then
      fail(owner .. " path contains an unsafe segment: " .. path)
    end
  end
end

local function fileExists(path)
  local file = io.open(path, "r")

  if not file then
    return false
  end

  file:close()
  return true
end

local manifest = dofile("src/manifest.lua")
assertType(manifest, "table", "Manifest")

local packageNames = {}

for name, target in pairs(manifest) do
  assertType(name, "string", "Manifest package name")
  assertType(target, "table", "Manifest entry " .. tostring(name))

  packageNames[name] = true

  local files = target.files or {}
  local depends = target.depends or {}

  assertType(files, "table", "Files for " .. name)
  assertType(depends, "table", "Dependencies for " .. name)

  local declaredFiles = {}

  for _, path in ipairs(files) do
    validateRelativePath(path, "File for " .. name)

    if declaredFiles[path] then
      fail("Duplicate file in package " .. name .. ": " .. path)
    end

    declaredFiles[path] = true

    local fullPath = SOURCE_ROOT .. "/" .. path

    if not fileExists(fullPath) then
      fail("Manifest file does not exist: " .. fullPath)
    end
  end

  if target.run ~= nil then
    validateRelativePath(target.run, "Entrypoint for " .. name)

    if not declaredFiles[target.run] then
      fail(
        "Entrypoint is not included in package files: "
        .. name .. ": " .. target.run
      )
    end
  end

  for _, dependency in ipairs(depends) do
    assertType(
      dependency,
      "string",
      "Dependency for " .. name
    )

    if not manifest[dependency] then
      fail(
        "Unknown dependency: "
        .. name .. " -> " .. dependency
      )
    end
  end
end

local visiting = {}
local visited = {}

local function visit(name)
  if visiting[name] then
    fail("Dependency cycle includes package: " .. name)
  end

  if visited[name] then
    return
  end

  visiting[name] = true

  for _, dependency in ipairs(manifest[name].depends or {}) do
    visit(dependency)
  end

  visiting[name] = nil
  visited[name] = true
end

for name in pairs(packageNames) do
  visit(name)
end

print("manifest: OK")
