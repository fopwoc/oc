local shell = require("shell")
local filesystem = require("filesystem")
local computer = require("computer")

local args = {...}

local DEFAULT_SOURCE = "https://raw.githubusercontent.com/USER/REPO/main/src"

local ROOT = shell.getWorkingDirectory()

local SOURCE_FILE = filesystem.concat(ROOT, ".source")
local INSTALLED_FILE = filesystem.concat(ROOT, ".installed.lua")
local MANIFEST_FILE = filesystem.concat(ROOT, "manifest.lua")

local function shellQuote(value)
  value = tostring(value)

  assert(
    not value:find("%z"),
    "Shell argument contains a NUL byte"
  )

  return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function readSource()
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

local function loadInstalled()
  if not filesystem.exists(INSTALLED_FILE) then
    return {}
  end

  local installed = assert(dofile(INSTALLED_FILE))

  assert(
    type(installed) == "table",
    "Invalid installed state"
  )

  return installed
end

local function serializeInstalled(installed)
  local values = {}

  for _, name in ipairs(installed) do
    values[#values + 1] = name
  end

  table.sort(values)

  local lines = {"return {"}

  for _, name in ipairs(values) do
    lines[#lines + 1] = string.format(
      "  %q,",
      name
    )
  end

  lines[#lines + 1] = "}"

  return table.concat(lines, "\n") .. "\n"
end

local function contains(list, value)
  for _, item in ipairs(list) do
    if item == value then
      return true
    end
  end

  return false
end

local function validateRelativePath(path)
  assert(
    type(path) == "string"
      and path ~= "",
    "Package path must be a non-empty string"
  )

  assert(
    path:sub(1, 1) ~= "/"
      and not path:find("\\", 1, true),
    "Package path must be relative and use '/' separators: " .. path
  )

  for segment in path:gmatch("[^/]+") do
    assert(
      segment ~= "."
        and segment ~= "..",
      "Package path contains an unsafe segment: " .. path
    )
  end

  return path
end

local function sourceUrl(source, path)
  return source:gsub("/+$", "") .. "/" .. path
end

local function createStage()
  local suffix = math.floor(computer.uptime() * 1000)
  local index = 0
  local path

  repeat
    index = index + 1
    path = filesystem.concat(
      ROOT,
      ".install-staging-"
        .. tostring(suffix)
        .. "-"
        .. tostring(index)
    )
  until not filesystem.exists(path)

  assert(
    filesystem.makeDirectory(path),
    "Failed to create staging directory: " .. path
  )

  return path
end

local function cleanupStage(stage)
  if filesystem.exists(stage) then
    filesystem.remove(stage)
  end
end

local function ensureParent(path)
  local directory = filesystem.path(path)

  if directory and not filesystem.exists(directory) then
    assert(
      filesystem.makeDirectory(directory),
      "Failed to create directory: " .. directory
    )
  end
end

local function writeFile(path, content)
  ensureParent(path)

  local file = assert(io.open(path, "w"))
  local ok, err = file:write(content)
  file:close()

  assert(ok, err or "Failed to write " .. path)
end

local function stageText(stage, name, content)
  local path = filesystem.concat(stage, name)
  writeFile(path, content)
  return path
end

local function stageDownloadPath(stage, path)
  validateRelativePath(path)
  return filesystem.concat(stage, path)
end

local function stageDownload(source, path, destination)
  validateRelativePath(path)
  ensureParent(destination)

  local command = table.concat({
    "wget",
    "-fq",
    shellQuote(sourceUrl(source, path)),
    shellQuote(destination),
  }, " ")

  local ok = shell.execute(command)

  assert(
    ok and filesystem.exists(destination),
    "Failed to download " .. path
  )
end

local function validateManifest(manifest)
  assert(
    type(manifest) == "table",
    "Invalid manifest"
  )

  for name, target in pairs(manifest) do
    assert(
      type(name) == "string"
        and name ~= "",
      "Manifest package name must be a non-empty string"
    )

    assert(
      type(target) == "table",
      "Invalid manifest entry: " .. name
    )

    if target.run ~= nil then
      validateRelativePath(target.run)
    end

    local files = target.files or {}
    local depends = target.depends or {}

    assert(
      type(files) == "table",
      "Manifest files must be a table: " .. name
    )

    assert(
      type(depends) == "table",
      "Manifest dependencies must be a table: " .. name
    )

    for _, path in ipairs(files) do
      validateRelativePath(path)
    end

    for _, dependency in ipairs(depends) do
      assert(
        type(dependency) == "string"
          and dependency ~= "",
        "Manifest dependency must be a non-empty string: " .. name
      )
    end
  end
end

local function loadRemoteManifest(source, stage)
  local path = stageDownloadPath(stage, "manifest.lua")

  stageDownload(
    source,
    "manifest.lua",
    path
  )

  local ok, manifest = pcall(dofile, path)

  assert(ok, manifest)
  validateManifest(manifest)

  return manifest, path
end

local function loadLocalManifest()
  assert(
    filesystem.exists(MANIFEST_FILE),
    "Local manifest is missing: " .. MANIFEST_FILE
  )

  local ok, manifest = pcall(dofile, MANIFEST_FILE)

  assert(ok, manifest)
  validateManifest(manifest)

  return manifest
end

local function commit(entries, stage)
  local committed = {}

  local ok, err = pcall(function()
    for index, entry in ipairs(entries) do
      local destination = entry.destination
      local backup = filesystem.concat(
        stage,
        ".backup-" .. tostring(index)
      )

      entry.backup = backup

      if filesystem.exists(destination) then
        assert(
          not filesystem.isDirectory(destination),
          "Cannot replace directory with package file: "
            .. destination
        )

        assert(
          filesystem.rename(destination, backup),
          "Failed to stage existing file: " .. destination
        )
      end

      ensureParent(destination)

      assert(
        filesystem.rename(entry.staged, destination),
        "Failed to install file: " .. destination
      )

      entry.committed = true
      committed[#committed + 1] = entry
    end
  end)

  if not ok then
    for index = #entries, 1, -1 do
      local entry = entries[index]

      if entry.committed and filesystem.exists(entry.destination) then
        filesystem.remove(entry.destination)
      end

      if entry.backup and filesystem.exists(entry.backup) then
        assert(
          filesystem.rename(entry.backup, entry.destination),
          "Failed to restore " .. entry.destination
        )
      end
    end

    error(err, 0)
  end

  for _, entry in ipairs(committed) do
    if entry.backup and filesystem.exists(entry.backup) then
      filesystem.remove(entry.backup)
    end
  end
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

local function addFile(files, path)
  validateRelativePath(path)
  files[path] = true
end

local function sortedFiles(files)
  local result = {}

  for path in pairs(files) do
    result[#result + 1] = path
  end

  table.sort(result)
  return result
end

local function resolvePackages(manifest, installed)
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

  return resolved
end

local function install(source, installed)
  local stage = createStage()

  local ok, err = pcall(function()
    local manifest, stagedManifest =
      loadRemoteManifest(source, stage)

    local resolved =
      resolvePackages(manifest, installed)

    local files = {}
    addFile(files, "run.lua")

    for name in pairs(resolved) do
      for _, path in ipairs(manifest[name].files or {}) do
        addFile(files, path)
      end
    end

    local entries = {
      {
        staged = stagedManifest,
        destination = MANIFEST_FILE,
      },
    }

    for _, path in ipairs(sortedFiles(files)) do
      local staged = stageDownloadPath(stage, path)

      print("Downloading " .. path)
      stageDownload(source, path, staged)

      entries[#entries + 1] = {
        staged = staged,
        destination = filesystem.concat(ROOT, path),
      }
    end

    entries[#entries + 1] = {
      staged = stageText(
        stage,
        ".installed.lua",
        serializeInstalled(installed)
      ),
      destination = INSTALLED_FILE,
    }

    entries[#entries + 1] = {
      staged = stageText(stage, ".source", source),
      destination = SOURCE_FILE,
    }

    commit(entries, stage)
  end)

  cleanupStage(stage)

  if not ok then
    error(err, 0)
  end
end

local source = readSource()
local installed = loadInstalled()

if args[1] == "--url" then
  assert(args[2], "Usage: install --url <url>")

  local configuredSource = args[2]:gsub("/+$", "")
  local stage = createStage()

  local ok, err = pcall(function()
    local staged = stageText(
      stage,
      ".source",
      configuredSource
    )

    commit({
      {
        staged = staged,
        destination = SOURCE_FILE,
      },
    }, stage)
  end)

  cleanupStage(stage)

  if not ok then
    error(err, 0)
  end

  print("Source: " .. configuredSource)
  return
end

if args[1] == "--list" then
  local stage = createStage()
  local remoteOk, remoteManifest, stagedManifest =
    pcall(loadRemoteManifest, source, stage)

  if remoteOk then
    remoteOk, remoteManifest = pcall(function()
      commit({
        {
          staged = stagedManifest,
          destination = MANIFEST_FILE,
        },
      }, stage)

      return remoteManifest
    end)
  end

  if remoteOk then
    cleanupStage(stage)
    listManifest(remoteManifest)
    return
  end

  local localOk, localManifest =
    pcall(loadLocalManifest)

  cleanupStage(stage)

  if localOk then
    print("Remote manifest unavailable; showing local manifest.")
    listManifest(localManifest)
    return
  end

  error(
    "Unable to load a remote or local manifest.\n"
      .. "Remote: " .. tostring(remoteManifest) .. "\n"
      .. "Local: " .. tostring(localManifest),
    0
  )
end

if args[1] == "all" then
  installed = {"all"}
elseif args[1] then
  if contains(installed, "all") then
    installed = {}
  end

  if not contains(installed, args[1]) then
    installed[#installed + 1] = args[1]
  end
elseif #installed == 0 then
  installed = {"all"}
end

install(source, installed)
print("Done.")
