local filesystem = require("filesystem")
local shell = require("shell")

local loader = {}

local function pathFor(workingDirectory, directory, filename)
  return filesystem.canonical(
    filesystem.concat(
      workingDirectory,
      directory,
      filename
    )
  )
end

function loader.load(options)
  assert(
    type(options) == "table",
    "Config loader requires options"
  )

  assert(
    type(options.directory) == "string"
      and options.directory ~= "",
    "Config loader requires a directory"
  )

  local displayName =
      options.displayName
      or options.directory

  local workingDirectory =
      options.workingDirectory
      or shell.getWorkingDirectory()

  local configPath =
      pathFor(
        workingDirectory,
        options.directory,
        options.filename or "config.lua"
      )

  local examplePath =
      pathFor(
        workingDirectory,
        options.directory,
        options.exampleFilename
          or "config.example.lua"
      )

  if not filesystem.exists(configPath) then
    error(
      displayName .. " configuration not found.\n"
      .. "\n"
      .. "Copy:\n"
      .. "  "
      .. examplePath
      .. "\n"
      .. "to:\n"
      .. "  "
      .. configPath
      .. "\n"
      .. "\n"
      .. "Then edit config.lua and restart "
      .. displayName
      .. "."
    )
  end

  local ok, config =
      pcall(dofile, configPath)

  if not ok then
    error(
      "Failed to load "
      .. displayName
      .. " configuration:\n"
      .. tostring(config)
    )
  end

  assert(
    type(config) == "table",
    displayName
      .. " configuration must return a table"
  )

  if options.validate then
    options.validate(config)
  end

  return config
end

return loader
