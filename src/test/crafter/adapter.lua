local ae2 = require("lib.ae2.network")
local resolver = require("lib.ae2.craftable")

local function craftableIdentity(value)
  return value.name
    or value.label
    or value.displayName
    or value.id
end

local adapter = ae2.create()

if not adapter:isAvailable() then
  print(
    "crafter adapter: SKIPPED "
    .. "(no ME controller or interface found)"
  )
else
  local fluids, fluidError =
      adapter:getFluidsInNetwork()

  if not fluids then
    print(
      "crafter adapter: SKIPPED "
      .. "(" .. tostring(fluidError) .. ")"
    )
  else
    local tested = false

    for _, fluid in ipairs(fluids) do
      if type(fluid) == "table"
          and type(fluid.name) == "string"
          and fluid.name ~= ""
      then
        local craftables, craftablesError =
            adapter:getCraftables({
              name = fluid.name,
            })

        assert(
          craftables,
          craftablesError
            or "getCraftables should return a table for a fluid name"
        )

        if #craftables > 0 then
          local resolved =
              resolver.resolve(
                adapter,
                {
                  type = "fluid",
                  name = fluid.name,
                }
              )

          assert(
            craftableIdentity(resolved)
              == craftableIdentity(craftables[1]),
            "native fluid resolver should return the matching craftable"
          )

          tested = true
          break
        end
      end
    end

    if tested then
      print("crafter adapter: OK (native fluid craftable)")
    else
      print(
        "crafter adapter: SKIPPED "
        .. "(no stored fluid has a craftable pattern)"
      )
    end
  end
end
