local storage = require("lib.storage.store")

local history = {}

local VERSION = 1

local function defaults()
  return {
    resolved = {},
  }
end

function history.create(options)
  options = options or {}

  local store = storage.open(
    options.namespace or "dashboard",
    options.record or "incidents",
    {
      version = VERSION,
      default = defaults,
      logger = options.logger,
    }
  )

  return {
    load = function()
      return store:load()
    end,

    save = function(_, state)
      local ok, errorMessage =
          pcall(store.save, store, state)

      if not ok and options.logger then
        pcall(
          options.logger,
          "failed to persist incident history: "
          .. tostring(errorMessage)
        )
      end

      return ok, errorMessage
    end,
  }
end

return history
