local compose = require("lib.compose.init")

local components = require("lib.components.init")

local telemetry = require("lib.telemetry.receiver")

local stateModule = require("app.dashboard.state")


local colors = {
  background = 0x111418,
  surface = 0x1A2026,
  border = 0x36414A,

  primary = 0x66CCFF,
  text = 0xD8DEE9,
  muted = 0x7F8C98,

  success = 0x66CC88,
  warning = 0xDDBB66,
  danger = 0xDD6666,
}


local STALE_AFTER =
    3

local OFFLINE_AFTER =
    10


local receiver =
    telemetry.create()

local dashboard =
    stateModule.create()


local function sourceStatus(source)
  local age =
      dashboard:age(source)

  if age >= OFFLINE_AFTER then
    return "OFFLINE",
        colors.danger
  end

  if age >= STALE_AFTER then
    return "STALE",
        colors.warning
  end

  return "ONLINE",
      colors.success
end


local function formatAge(age)
  if age < 1 then
    return "<1s"
  end

  return tostring(
    math.floor(age)
  ) .. "s"
end


local function formatUptime(seconds)
  seconds =
      math.floor(
        seconds or 0
      )

  local hours =
      math.floor(
        seconds / 3600
      )

  local minutes =
      math.floor(
        (seconds % 3600) / 60
      )

  if hours > 0 then
    return tostring(hours)
        .. "h "
        .. tostring(minutes)
        .. "m"
  end

  return tostring(minutes)
      .. "m"
end

local function formatNumber(value)
  value =
      math.floor(
        tonumber(value) or 0
      )

  local text =
      tostring(value)

  while true do
    local formatted, count =
        text:gsub(
          "^(-?%d+)(%d%d%d)",
          "%1,%2"
        )

    text = formatted

    if count == 0 then
      break
    end
  end

  return text
end


compose.App(function()
  local revision =
      compose.remember(0)

  compose.DisposableEffect(
    "telemetry-port",
    function()
      receiver:open()

      return function()
        receiver:close()
      end
    end
  )


  compose.LaunchedEffect(
    "telemetry",
    function()
      while true do
        local packet =
            receiver:receive(
              compose.awaitEvent(
                "modem_message"
              )
            )

        if packet then
          dashboard:update(packet)

          revision.value =
              revision.value + 1
        end
      end
    end
  )

  compose.LaunchedEffect(
    "clock",
    function()
      while true do
        compose.delay(1)

        revision.value =
            revision.value + 1
      end
    end
  )


  local _ =
      revision.value

  local sources =
      dashboard:all()

  local function colored(text, color)
    return {
      text = tostring(text),
      color = color,
    }
  end

  local function metric(value, color)
    return colored(
      formatNumber(value),
      color or colors.text
    )
  end

  local function gridCell(value, row)
    if type(value) == "table" then
      return compose.Text(
        value.text,
        compose.Modifier:foreground(
          value.color or colors.text
        )
      )
    end

    return compose.Text(
      tostring(value or ""),
      compose.Modifier:foreground(
        row == 1
        and colors.primary
        or colors.text
      )
    )
  end

  local gridRows = {
    {
      "SOURCE",
      "STATE",
      "TYPE",
      "TARGET",
      "CRAFT",
      "WAIT",
      "REQ",
      "DONE",
      "CANCEL",
      "COOL",
      "SEEN",
      "UP",
    },
  }

  for _, source in ipairs(sources) do
    local status,
    statusColor =
        sourceStatus(source)

    local age =
        dashboard:age(source)

    local data =
        source.data or {}

    if source.source == "crafter" then
      local activity =
          data.playing
          and "RUNNING"
          or "PAUSED"

      local activityColor =
          data.playing
          and colors.success
          or colors.warning

      if status ~= "ONLINE" then
        activity = status
        activityColor = statusColor
      end

      gridRows[#gridRows + 1] = {
        colored(source.id, colors.primary),
        colored(activity, activityColor),
        colored(source.source, colors.muted),
        metric(data.targets),
        metric(data.crafting, colors.success),
        metric(data.waiting),
        metric(data.requests),
        metric(data.completed, colors.success),
        metric(data.canceled, colors.danger),
        metric(data.cooldown, colors.warning),
        colored(formatAge(age), colors.muted),
        colored(
          formatUptime(source.remoteUptime),
          colors.muted
        ),
      }
    else
      gridRows[#gridRows + 1] = {
        colored(source.id, colors.primary),
        colored(status, statusColor),
        colored(source.source, colors.muted),
        "-",
        "-",
        "-",
        "-",
        "-",
        "-",
        "-",
        colored(formatAge(age), colors.muted),
        colored(
          formatUptime(source.remoteUptime),
          colors.muted
        ),
      }
    end
  end

  if #sources == 0 then
    gridRows[#gridRows + 1] = {
      colored(
        "WAITING FOR TELEMETRY",
        colors.muted
      ),
    }
  end

  local dashboardGrid =
      components.Grid({
        rows = gridRows,
        columns = {
          {weight = 2, align = "left"},
          {weight = 1, align = "left"},
          {weight = 1, align = "left"},
          {weight = 1, align = "right"},
          {weight = 1, align = "right"},
          {weight = 1, align = "right"},
          {weight = 1, align = "right"},
          {weight = 1, align = "right"},
          {weight = 1, align = "right"},
          {weight = 1, align = "right"},
          {weight = 1, align = "right"},
          {weight = 1, align = "right"},
        },
        appearance = "alternating",
        oddBackground = colors.background,
        evenBackground = colors.surface,
        cellPadding = 0,
        cell = gridCell,
        modifier = compose.Modifier:fillMaxWidth(),
      })


  return components.Entrypoint({
    title = "Dashboard",
    colors = colors,
    service = "Telemetry :4242",
    topBarActions = function()
      return compose.Text(
        tostring(#sources) .. " SOURCES",
        compose.Modifier:foreground(colors.muted)
      )
    end,
    content = compose.Column(
      {
        dashboardGrid,
      },
      compose.Modifier
      :fillMaxWidth()
      :fillMaxHeight()
      :padding(1)
    ),
  })
end)
