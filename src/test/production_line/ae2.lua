local ae2 = require("lib.ae2.network")

local adapter = ae2.create()

if not adapter:isAvailable() then
  print("production line AE2 adapter: SKIPPED (no ME component)")
else
  local fluids, fluidError =
      adapter:getFluidsInNetwork()

  if not fluids then
    print(
      "production line AE2 adapter: SKIPPED ("
      .. tostring(fluidError)
      .. ")"
    )
  else
    assert(type(fluids) == "table")

    local fluidName = "__oc_fluid_test__"

    if fluids[1] then
      assert(
        type(fluids[1].name) == "string"
          and tonumber(fluids[1].amount) ~= nil,
        "fluid entries should expose name and numeric amount"
      )

      fluidName = fluids[1].name
    end

    local values, errorMessage =
        adapter:sample(
          {
            {
              type = "fluid",
              key = "fluid",
              name = fluidName,
            },
          },
          function(resource)
            return resource.key
          end
        )

    assert(
      values and type(values.fluid) == "number",
      errorMessage
        or "fluid resource should produce a numeric amount"
    )

    print("production line AE2 adapter: OK")
  end
end
