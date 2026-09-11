local compose =
    require("lib.compose.init")

local computer =
    require("computer")

local components =
    require("lib.components.init")

local configLoader =
    require("lib.config.loader")

local schedulerModule =
    require("app.crafter.scheduler")

local telemetry =
    require("lib.telemetry.sender")


local colors = components.ColorStyle()
local cells = components.GridCells(colors)


local function statusInfo(target)
  if target.status == "crafting" then
    return "CRAFTING",
        colors.good
  end

  if target.status == "requesting" then
    return "REQUESTING",
        colors.warning
  end

  if target.resolveError then
    return "RETRYING",
        colors.warning
  end

  if target.status == "cooldown" then
    return "COOLDOWN",
        colors.warning
  end

  if target.status == "ready" then
    return "READY",
        colors.good
  end

  return "WAITING",
      colors.muted
end


local config =
    configLoader.load({
      directory = "app/crafter",
      displayName = "Crafter",
    })

local scheduler =
    schedulerModule.create(
      config
    )

local telemetrySender =
    telemetry.create({
      source = "crafter",
      id = "main-crafter",
    })


compose.App(function()
  local playing =
      compose.remember(true)

  local revision =
      compose.remember(0)


  compose.LaunchedEffect(
    "scheduler",
    function()
      while true do
        scheduler:step(
          playing.value
        )

        revision.value =
            revision.value + 1

        compose.delay(0.25)
      end
    end
  )


  compose.LaunchedEffect(
    "telemetry",
    function()
      while true do
        telemetrySender:send(
          scheduler:snapshot(
            playing.value
          )
        )

        compose.delay(1)
      end
    end
  )


  return components.Entrypoint({
    title = "Crafter",
    service = "scheduler",
    topBarActions = function()
      return compose.Row({
        compose.Text(
          tostring(#scheduler.targets) .. " TARGETS",
          compose.Modifier:foreground(colors.muted)
        ),
        compose.Spacer(compose.Modifier:width(1)),
        compose.Text(
          playing.value
          and "● RUNNING"
          or "● PAUSED",
          compose.Modifier:foreground(
            playing.value
            and colors.good
            or colors.bad
          )
        ),
      })
    end,
    bottomBarActions = function(context)
      return compose.Row({
        components.TelemetryStatus(telemetrySender, context),
        components.Button(
          playing.value
          and "PAUSE"
          or "PLAY",
          function()
            playing.value = not playing.value
          end,
          compose.Modifier:foreground(
            playing.value
            and colors.warning
            or colors.good
          )
        ),
      })
    end,
    content = function()
      local _ = revision.value
      local rows = {
        {
          "TARGET",
          "STOCK",
          "STATE",
          "DONE/H",
          "DETAIL",
        },
      }

      for _, target in ipairs(scheduler.targets) do
        local status, statusColor = statusInfo(target)
        local detail =
            target.amountError
            or target.resolveError
            or (
              target.status == "crafting"
              and "request active"
              or "--"
            )

        rows[#rows + 1] = {
          cells:colored(target.label, colors.primary),
          cells:colored(
            tostring(target.currentAmount)
              .. "/"
              .. tostring(target.amount),
            colors.text
          ),
          cells:colored(status, statusColor),
          cells:colored(
            string.format(
              "%.1f",
              target.completions:perHour(computer.uptime())
            ),
            colors.good
          ),
          cells:colored(
            detail,
            (target.amountError or target.resolveError)
              and colors.warning
              or colors.muted
          ),
        }
      end

      return compose.Column(
        {
          components.Section("TARGET QUEUE", {
            components.Grid({
              rows = rows,
              columns = {
                {weight = 4, align = "left"},
                {weight = 2, align = "right"},
                {weight = 2, align = "left"},
                {weight = 2, align = "right"},
                {weight = 5, align = "left"},
              },
              appearance = "alternating",
              horizontalCellPadding = 1,
              cell = cells.render,
              modifier = compose.Modifier:fillMaxWidth(),
            }),
          }),
          compose.Spacer(compose.Modifier:weight(1)),
        },
        compose.Modifier
        :fillMaxWidth()
        :fillMaxHeight()
      )
    end,
  })
end)
