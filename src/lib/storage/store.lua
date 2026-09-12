local filesystem = require("filesystem")
local serialization = require("serialization")
local shell = require("shell")

local storage = {}

local DATA_DIRECTORY = ".data"

local function assertSegment(value, label)
  assert(
    type(value) == "string"
      and value ~= "",
    "Storage " .. label .. " must be a non-empty string"
  )

  assert(
    value ~= "."
      and value ~= ".."
      and not value:find("/", 1, true)
      and not value:find("\\", 1, true),
    "Storage " .. label .. " must be one path segment: " .. value
  )

  return value
end

local function ensureDirectory(path)
  if filesystem.exists(path) then
    assert(
      filesystem.isDirectory(path),
      "Storage path is not a directory: " .. path
    )

    return
  end

  local parent = filesystem.path(path)

  if parent
      and parent ~= path
      and not filesystem.exists(parent)
  then
    ensureDirectory(parent)
  end

  local ok, err =
      filesystem.makeDirectory(path)

  if not ok and not filesystem.isDirectory(path) then
    error(
      "Failed to create storage directory: "
      .. path
      .. ": "
      .. tostring(err)
    )
  end
end

local function readText(path)
  local file, err = io.open(path, "r")

  if not file then
    return nil, err
  end

  local ok, text = pcall(function()
    return file:read("*a")
  end)

  local closeOk, closeError = pcall(function()
    return file:close()
  end)

  if not ok then
    return nil, text
  end

  if not closeOk then
    return nil, closeError
  end

  return text
end

local function writeText(path, text)
  local file, err = io.open(path, "w")

  if not file then
    return nil, err
  end

  local ok, writeError = pcall(function()
    assert(file:write(text))
  end)

  local closeOk, closeError = pcall(function()
    return file:close()
  end)

  if not ok then
    return nil, writeError
  end

  if not closeOk then
    return nil, closeError
  end

  return true
end

-- Storage runs underneath compose applications, so failures are recorded
-- instead of printed over the framebuffer.
local function report(instance, message)
  instance.lastError = message

  if instance.logger then
    pcall(instance.logger, message)
  end
end

-- OpenComputers disks are tiny; refuse writes that would fill the disk
-- instead of leaving a truncated record behind.
local SPACE_MARGIN = 4096

local function freeSpace(path)
  local ok, proxy = pcall(filesystem.get, path)

  if not ok
      or type(proxy) ~= "table"
      or type(proxy.spaceTotal) ~= "function"
      or type(proxy.spaceUsed) ~= "function"
  then
    return nil
  end

  local totalOk, total = pcall(proxy.spaceTotal)
  local usedOk, used = pcall(proxy.spaceUsed)

  if not totalOk
      or not usedOk
      or type(total) ~= "number"
      or type(used) ~= "number"
  then
    return nil
  end

  return math.max(0, total - used)
end

local function fileSize(path)
  if not filesystem.exists(path) then
    return 0
  end

  local ok, size = pcall(filesystem.size, path)

  if ok and type(size) == "number" then
    return size
  end

  return 0
end

local function freshState(instance)
  local state = instance.default()

  assert(
    type(state) == "table",
    "Storage default factory must return a table"
  )

  state.version = instance.version

  return state
end

local function persistFresh(instance, reason)
  local state = freshState(instance)
  local ok, err = pcall(instance.save, instance, state)

  if not ok then
    report(
      instance,
      (reason and reason .. "; " or "")
      .. "fresh state could not be persisted: "
      .. tostring(err)
    )
  elseif reason then
    report(instance, reason .. "; reset to defaults")
  end

  return state
end

function storage.open(namespace, name, options)
  assertSegment(namespace, "namespace")
  assertSegment(name, "record name")

  assert(
    type(options) == "table",
    "Storage options are required"
  )

  assert(
    type(options.version) == "number",
    "Storage version must be a number"
  )

  assert(
    type(options.default) == "function",
    "Storage default must be a function"
  )

  local root = filesystem.canonical(
    filesystem.concat(
      shell.getWorkingDirectory(),
      DATA_DIRECTORY
    )
  )

  local namespacePath = filesystem.concat(
    root,
    namespace
  )

  local path = filesystem.concat(
    namespacePath,
    name
  )

  ensureDirectory(namespacePath)

  local instance = {
    namespace = namespace,
    name = name,
    version = options.version,
    default = options.default,
    logger = options.logger,
    directory = namespacePath,
    path = path,
    temporaryPath = path .. ".tmp",
  }

  function instance:save(state)
    assert(
      type(state) == "table",
      "Storage state must be a table"
    )

    state.version = self.version

    local ok, serialized =
        pcall(serialization.serialize, state)

    assert(
      ok and type(serialized) == "string",
      "Failed to serialize storage state: "
      .. tostring(serialized)
    )

    if filesystem.exists(self.path) then
      assert(
        not filesystem.isDirectory(self.path),
        "Storage record path is a directory: " .. self.path
      )
    end

    local free = freeSpace(self.directory)

    if free
        and #serialized + SPACE_MARGIN > free + fileSize(self.path)
    then
      error(
        "Not enough disk space for storage record ("
        .. tostring(#serialized)
        .. " bytes, "
        .. tostring(free)
        .. " free)"
      )
    end

    if free and #serialized + SPACE_MARGIN > free then
      -- The new record only fits in the space the old one occupies. The
      -- temporary file still guards against a torn write because load()
      -- recovers it when the record itself is missing.
      pcall(filesystem.remove, self.path)
    end

    local written, writeError =
        writeText(self.temporaryPath, serialized)

    if not written then
      pcall(filesystem.remove, self.temporaryPath)
      error(
        "Failed to write storage temporary file: "
        .. tostring(writeError)
      )
    end

    if filesystem.exists(self.path) then
      pcall(filesystem.remove, self.path)
    end

    local committed, commitError =
        filesystem.rename(
          self.temporaryPath,
          self.path
        )

    if not committed then
      pcall(filesystem.remove, self.temporaryPath)

      error(
        "Failed to replace storage record: "
        .. tostring(commitError)
      )
    end

    self.lastError = nil
    self.lastSize = #serialized

    return state
  end

  function instance:load()
    if filesystem.exists(self.temporaryPath) then
      if filesystem.exists(self.path) then
        pcall(filesystem.remove, self.temporaryPath)
      else
        -- A completed temporary file whose commit was interrupted.
        filesystem.rename(self.temporaryPath, self.path)
      end
    end

    if not filesystem.exists(self.path) then
      return persistFresh(
        self,
        nil
      )
    end

    local text, readError = readText(self.path)

    if not text then
      return persistFresh(
        self,
        "record read failed: " .. tostring(readError)
      )
    end

    local ok, state =
        pcall(
          serialization.unserialize,
          text
        )

    if not ok then
      return persistFresh(
        self,
        "unserialization failed: " .. tostring(state)
      )
    end

    if type(state) ~= "table" then
      return persistFresh(
        self,
        "stored root is not a table"
      )
    end

    if state.version ~= self.version then
      return persistFresh(
        self,
        "schema version mismatch"
      )
    end

    return state
  end

  function instance:trySave(state)
    local ok, result = pcall(self.save, self, state)

    if not ok then
      report(self, "record save failed: " .. tostring(result))
      return false, result
    end

    return true, result
  end

  function instance:reset()
    return self:save(
      freshState(self)
    )
  end

  return instance
end

return storage
