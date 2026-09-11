local filesystem = require("filesystem")
local serialization = require("serialization")
local shell = require("shell")
local storage = require("lib.storage.store")

local testNamespaces = {
  "__storage_test__",
  "__storage_test_a__",
  "__storage_test_b__",
}

local dataRoot = filesystem.concat(
  shell.getWorkingDirectory(),
  ".data"
)

local function cleanup()
  for _, namespace in ipairs(testNamespaces) do
    local path = filesystem.concat(
      dataRoot,
      namespace
    )

    if filesystem.exists(path) then
      filesystem.remove(path)
    end
  end
end

cleanup()

local function defaults()
  return {
    samples = {},
    cursor = 1,
  }
end

local store = storage.open(
  "__storage_test__",
  "history",
  {
    version = 1,
    default = defaults,
  }
)

assert(
  filesystem.exists(store.directory),
  "storage should create missing namespace directories"
)

local fresh = store:load()

assert(
  fresh.version == 1
    and #fresh.samples == 0
    and fresh.cursor == 1,
  "missing records should load default state"
)

fresh.samples[1] = {
  time = 123,
  nested = {
    value = 456,
  },
}

store:save(fresh)

local roundTrip = store:load()

assert(
  roundTrip.samples[1].nested.value == 456,
  "nested tables should survive serialization"
)

local function writeSerialized(path, value)
  local file = assert(io.open(path, "w"))
  assert(file:write(serialization.serialize(value)))
  file:close()
end

writeSerialized(store.path, "not a table")

local nonTable = store:load()

assert(
  nonTable.version == 1
    and #nonTable.samples == 0,
  "non-table roots should reset to defaults"
)

local corruptFile = assert(io.open(store.path, "w"))
assert(corruptFile:write("{ this is not serialized data"))
corruptFile:close()

local recovered = store:load()

assert(
  recovered.version == 1
    and #recovered.samples == 0,
  "corrupted records should reset to defaults"
)

writeSerialized(store.path, {
  version = 2,
  samples = {
    "old schema",
  },
})

local versionReset = store:load()

assert(
  versionReset.version == 1
    and #versionReset.samples == 0,
  "schema version changes should reset the record"
)

versionReset.samples[1] = "temporary"
store:save(versionReset)

local reset = store:reset()

assert(
  reset.version == 1
    and #reset.samples == 0,
  "reset should recreate and persist defaults"
)

store:save({
  samples = {
    "valid record",
  },
})

local temporary = assert(io.open(store.temporaryPath, "w"))
assert(temporary:write("incomplete temporary record"))
temporary:close()

local afterTemporary = store:load()

assert(
  afterTemporary.samples[1] == "valid record"
    and not filesystem.exists(store.temporaryPath),
  "stale temporary writes must not replace valid records"
)

local save = store.save
local loggedFailure

store.logger = function(message)
  loggedFailure = message
end

store.save = function()
  error("simulated write failure")
end

local saved, saveError = store:trySave({samples = {}})

assert(
  not saved
    and tostring(saveError):find("simulated write failure", 1, true)
    and loggedFailure,
  "trySave should report write failures without crashing the application"
)

store.save = save

local firstNamespace = storage.open(
  "__storage_test_a__",
  "same-name",
  {
    version = 1,
    default = function()
      return {owner = "a"}
    end,
  }
)

local secondNamespace = storage.open(
  "__storage_test_b__",
  "same-name",
  {
    version = 1,
    default = function()
      return {owner = "b"}
    end,
  }
)

firstNamespace:save(firstNamespace:load())
secondNamespace:save(secondNamespace:load())

assert(
  firstNamespace:load().owner == "a"
    and secondNamespace:load().owner == "b",
  "namespaces must not collide"
)

cleanup()

print("storage: OK")
