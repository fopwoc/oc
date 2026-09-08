local serialization =
    require("serialization")

local protocol = {}

protocol.NAME =
"oc-telemetry"

protocol.VERSION =
    1

protocol.DEFAULT_PORT =
    4242


function protocol.encode(
    source,
    id,
    uptime,
    data,
    event
)
  assert(
    type(source) == "string",
    "Telemetry source must be a string"
  )

  assert(
    type(id) == "string",
    "Telemetry id must be a string"
  )

  assert(
    type(uptime) == "number",
    "Telemetry uptime must be a number"
  )

  assert(
    type(data) == "table",
    "Telemetry data must be a table"
  )

  return serialization.serialize({
    protocol =
        protocol.NAME,

    version =
        protocol.VERSION,

    source =
        source,

    id =
        id,

    uptime =
        uptime,

    data =
        data,

    event =
        event,
  })
end

function protocol.decode(payload)
  if type(payload) ~= "string" then
    return nil
  end

  local ok, packet =
      pcall(
        serialization.unserialize,
        payload
      )

  if
      not ok
      or type(packet) ~= "table"
  then
    return nil
  end

  if
      packet.protocol ~= protocol.NAME
      or packet.version ~= protocol.VERSION
  then
    return nil
  end

  if
      type(packet.source) ~= "string"
      or type(packet.id) ~= "string"
      or type(packet.uptime) ~= "number"
      or type(packet.data) ~= "table"
      or (
        packet.event ~= nil
        and type(packet.event) ~= "string"
      )
  then
    return nil
  end

  packet.event = packet.event
      or "telemetry"

  return packet
end

return protocol
