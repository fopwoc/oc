local component = require("component")
local resolver = require("lib.ae2.craftable")

local function craftableIdentity(value)
  return value.name
    or value.label
    or value.displayName
    or value.id
end

local function firstAddress(componentType)
  local iterator = component.list(componentType)
  return iterator()
end

local address =
    firstAddress("me_controller")
    or firstAddress("me_interface")

if not address then
  print("crafter fluid resolver: SKIPPED (no ME component)")
else
  local proxy = assert(component.proxy(address))

  local fluidOk, fluids =
      pcall(function()
        return proxy.getFluidsInNetwork()
      end)

  if not fluidOk or type(fluids) ~= "table" then
    print(
      "crafter fluid resolver: SKIPPED "
      .. "(fluid API unavailable)"
    )
  else
    assert(
      fluidOk,
      "getFluidsInNetwork should return a table"
    )

    local tested = false

    for _, fluid in ipairs(fluids) do
      local ok, values =
          pcall(function()
            return proxy.getCraftables({
              name = fluid.name,
            })
          end)

      assert(
        ok and type(values) == "table",
        "getCraftables should return a table for native fluids"
      )

      if #values > 0 then
        local resolved =
            resolver.resolve(
              proxy,
              {
                type = "fluid",
                name = fluid.name,
              }
            )

        assert(
          craftableIdentity(resolved)
            == craftableIdentity(values[1]),
          "fluid resolver should return the native fluid craftable"
        )

        tested = true
        break
      end
    end

      if tested then
        print("crafter fluid resolver: OK")
      else
        print(
          "crafter fluid resolver: SKIPPED "
          .. "(no craftable fluid in the ME network)"
        )
      end
    end
end
