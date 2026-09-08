local powerAdapter = require("lib.gt.lapotronic")

local address = powerAdapter.firstAddress()

if not address then
  print(
    "power adapter: SKIPPED "
    .. "(no compatible gt_machine component found)"
  )
else
  local adapter = powerAdapter.create()
  local values, errorMessage =
      adapter:sample({
        id = "adapter-test",
        address = address,
      })

  if not values then
    print(
      "power adapter: SKIPPED (energy API unavailable: "
      .. tostring(errorMessage)
      .. ")"
    )
  else
    assert(
      type(values.stored) == "string"
        and type(values.capacity) == "string"
        and type(values.input) == "number"
        and type(values.output) == "number",
      "power adapter should return complete energy data"
    )

    print("power adapter: OK")
  end
end
