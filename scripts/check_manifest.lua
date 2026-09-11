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
local fileOwners = {}
local moduleOwners = {}

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

    if fileOwners[path] then
      fail(
        "File belongs to multiple packages: "
        .. path
        .. " ("
        .. fileOwners[path]
        .. ", "
        .. name
        .. ")"
      )
    end

    declaredFiles[path] = true
    fileOwners[path] = name

    if path:sub(-4) == ".lua" then
      moduleOwners[
        path:sub(1, -5):gsub("/", ".")
      ] = name
    end

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

local dependencyClosures = {}

local function dependenciesOf(name)
  local result = dependencyClosures[name]

  if result then
    return result
  end

  result = {[name] = true}
  dependencyClosures[name] = result

  for _, dependency in ipairs(manifest[name].depends or {}) do
    result[dependency] = true

    for transitive in pairs(dependenciesOf(dependency)) do
      result[transitive] = true
    end
  end

  return result
end

local function checkRequiredModule(owner, path, moduleName)
  local dependency = moduleOwners[moduleName]

  if dependency
      and not dependenciesOf(owner)[dependency]
  then
    fail(
      "Missing package dependency for "
      .. path
      .. ": "
      .. owner
      .. " -> "
      .. dependency
      .. " (requires "
      .. moduleName
      .. ")"
    )
  end
end

for path, owner in pairs(fileOwners) do
  local file = assert(io.open(SOURCE_ROOT .. "/" .. path, "r"))
  local source = assert(file:read("*a"))
  file:close()

  for moduleName in source:gmatch('require%s*%(%s*"([^"]+)"') do
    checkRequiredModule(owner, path, moduleName)
  end

  for moduleName in source:gmatch("require%s*%(%s*'([^']+)'") do
    checkRequiredModule(owner, path, moduleName)
  end
end

local sourceFiles = io.popen(
  "find src/lib src/app src/script -type f -name '*.lua' -print"
)

assert(sourceFiles, "Failed to list production source files")

for fullPath in sourceFiles:lines() do
  local path = fullPath:sub(#SOURCE_ROOT + 2)

  if not fileOwners[path] then
    fail("Production source is missing from manifest: " .. path)
  end
end


local closed, closeReason, closeCode = sourceFiles:close()

if not closed then
  fail(
    "Failed to list production source files: "
    .. tostring(closeReason)
    .. " "
    .. tostring(closeCode)
  )
end

print("manifest: OK")
