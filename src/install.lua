local shell = require("shell")
local filesystem = require("filesystem")

local args = {...}

local DEFAULT_SOURCE = "https://raw.githubusercontent.com/USER/REPO/main/src"

local ROOT = shell.getWorkingDirectory()

local SOURCE_FILE = filesystem.concat(ROOT, ".source")
local INSTALLED_FILE = filesystem.concat(ROOT, ".installed.lua")
local MANIFEST_FILE = filesystem.concat(ROOT, "manifest.lua")

local function loadSource()
  if not filesystem.exists(SOURCE_FILE) then
    return DEFAULT_SOURCE
  end

  local file = assert(io.open(SOURCE_FILE, "r"))
  local source = file:read("*l")
  file:close()

  if not source or source == "" then
    return DEFAULT_SOURCE
  end

  return source
end

local function saveSource(source)
    local file = assert(io.open(SOURCE_FILE, "w"))
    file:write(source, "\n")
    file:close()
end

local function loadInstalled()
  if not filesystem.exists(INSTALLED_FILE) then
    return {}
  end

  local installed = assert(dofile(INSTALLED_FILE))
  assert(type(installed) == "table", "Invalid installed state")

  return installed
end

local function saveInstalled(installed)
  table.sort(installed)

  local file = assert(io.open(INSTALLED_FILE, "w"))

  file:write("return {\n")

  for _, name in ipairs(installed) do
    file:write(string.format("  %q,\n", name))
  end

  file:write("}\n")
  file:close()
end

local function contains(list, value)
  for _, item in ipairs(list) do
    if item == value then
      return true
    end
  end

  return false
end

local function download(source, path, destination)
  if filesystem.exists(destination) then
    filesystem.remove(destination)
  end

  local ok = shell.execute(
    "wget -fq " .. source .. "/" .. path .. " " .. destination
  )

  assert(ok, "Failed to download " .. path)
end

local source = loadSource()
local installed = loadInstalled()

if args[1] == "--url" then
    assert(args[2], "Usage: install --url <url>")

    source = args[2]:gsub("/+$", "")
    saveSource(source)

    print("Source: " .. source)
    return
end

local function loadRemoteManifest(source)
  download(source, "manifest.lua", MANIFEST_FILE)

  local ok, manifest = pcall(dofile, MANIFEST_FILE)

  assert(ok, manifest)
  assert(type(manifest) == "table", "Invalid manifest")

  return manifest
end

local function listManifest(manifest)
  local names = {}

  for name, target in pairs(manifest) do
    if target.run then
      table.insert(names, name)
    end
  end

  table.sort(names)

  print("Available:")
  print()

  for _, name in ipairs(names) do
    local target = manifest[name]

    print(string.format(
      "  %-12s %s",
      name,
      target.description or ""
    ))
  end
end

if args[1] == "--list" then
  local manifest = loadRemoteManifest(source)
  listManifest(manifest)
  return
end

if args[1] == "all" then
  installed = {"all"}
elseif args[1] then
  local name = args[1]

  if contains(installed, "all") then
    installed = {}
  end

  if not contains(installed, name) then
    table.insert(installed, name)
  end
end

local manifest = loadRemoteManifest(source)

local resolved = {}

local function resolve(name)
  if resolved[name] then
    return
  end

  local target = manifest[name]
  assert(target, "Unknown target: " .. name)

  resolved[name] = true

  for _, dependency in ipairs(target.depends or {}) do
    resolve(dependency)
  end
end

if #installed == 0 or contains(installed, "all") then
  for name in pairs(manifest) do
    resolve(name)
  end
else
  for _, name in ipairs(installed) do
    resolve(name)
  end
end

local files = {
  ["run.lua"] = true,
}

for name in pairs(resolved) do
  for _, path in ipairs(manifest[name].files or {}) do
    files[path] = true
  end
end

for path in pairs(files) do
  local destination = filesystem.concat(ROOT, path)
  local directory = filesystem.path(destination)

  if directory and not filesystem.exists(directory) then
    filesystem.makeDirectory(directory)
  end

  print("Installing " .. path)
  download(source, path, destination)
end

saveInstalled(installed)
saveSource(source)

print("Done.")
