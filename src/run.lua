local shell = require("shell")
local filesystem = require("filesystem")

local ROOT = shell.getWorkingDirectory()

package.path = table.concat({
    filesystem.concat(ROOT, "?.lua"),
    filesystem.concat(ROOT, "?/init.lua"),
    package.path,
  }, ";")

local function matchesModulePrefix(
    moduleName,
    prefix
)
  if moduleName == prefix then
    return true
  end

  if moduleName:sub(1, #prefix + 1)
      == prefix .. "/"
  then
    return true
  end

  return moduleName:sub(1, #prefix + 1)
      == prefix .. "."
end

local function reloadProjectModules()
  local modulePrefixes = {
    "../lib",
    "../app",
    "lib",
    "app",
  }

  local loadedModules = {}

  for moduleName in pairs(package.loaded) do
    for _, prefix in ipairs(modulePrefixes) do
      if matchesModulePrefix(moduleName, prefix) then
        loadedModules[#loadedModules + 1] =
            moduleName
        break
      end
    end
  end

  for _, moduleName in ipairs(loadedModules) do
    package.loaded[moduleName] = nil
  end
end

reloadProjectModules()

local INSTALLED_FILE = filesystem.concat(ROOT, ".installed.lua")
local MANIFEST_FILE = filesystem.concat(ROOT, "manifest.lua")

local args = { ... }
local requested = args[1]

local function loadInstalled()
  if not filesystem.exists(INSTALLED_FILE) then
    return {}
  end

  local installed = assert(dofile(INSTALLED_FILE))

  assert(type(installed) == "table", "Invalid installed state")

  return installed
end

local manifest = assert(dofile(MANIFEST_FILE))
local installed = loadInstalled()

local resolved = {}

local function resolve(name)
  if resolved[name] then
    return
  end

  local target = manifest[name]

  if not target then
    return
  end

  resolved[name] = true

  for _, dependency in ipairs(target.depends or {}) do
    resolve(dependency)
  end
end

local all = false

for _, name in ipairs(installed) do
  if name == "all" then
    all = true
    break
  end
end

if all then
  for name in pairs(manifest) do
    resolve(name)
  end
else
  for _, name in ipairs(installed) do
    resolve(name)
  end
end

local function help()
  print("Usage: run <name> [args...]")
  print()
  print("Available:")

  local names = {}

  for name in pairs(resolved) do
    local target = manifest[name]

    if target and target.run then
      table.insert(names, name)
    end
  end

  table.sort(names)

  for _, name in ipairs(names) do
    local target = manifest[name]

    print(string.format(
      "  %-12s %s",
      name,
      target.description or ""
    ))
  end
end

if not requested or requested == "help" or requested == "-h" or requested == "--help" then
  help()
  return
end

if not resolved[requested] then
  error("Target is not installed: " .. requested, 0)
end

local target = manifest[requested]

if not target.run then
  error("Target is not runnable: " .. requested, 0)
end

local path = filesystem.concat(ROOT, target.run)

if not filesystem.exists(path) then
  error("Entrypoint is missing: " .. path, 0)
end

table.remove(args, 1)

local chunk, err = loadfile(path)

if not chunk then
  error(err, 0)
end

chunk(table.unpack(args))
