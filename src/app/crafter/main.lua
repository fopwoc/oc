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


  --
  -- Depend on scheduler snapshots.
  --
  local _ =
      revision.value


  local rows = {}


  for _, target in ipairs(
    scheduler.targets
  ) do
    local status,
    statusColor =
        statusInfo(target)

    rows[#rows + 1] =
        components.Card(
          {
            compose.Column({
              compose.Row({
                  compose.Text(
                    target.label,
                    compose.Modifier
                    :foreground(
                      colors.primary
                    )
                  ),

                  compose.Spacer(
                    compose.Modifier
                    :weight(1)
                  ),

                  compose.Text(
                    status,
                    compose.Modifier
                    :foreground(
                      statusColor
                    )
                  ),
                },
                compose.Modifier
                :fillMaxWidth()
              ),

              compose.Text(
                "amount "
                .. tostring(
                  target.currentAmount
                )
                .. "/"
                .. tostring(target.amount)
                .. "   done/h "
                .. string.format(
                  "%.1f",
                  target.completions:perHour(computer.uptime())
                ),
                compose.Modifier
                :foreground(
                  colors.muted
                )
              ),
            })
          },

          compose.Modifier
          :fillMaxWidth()
          :background(
            colors.surface
          ),

          {
            color =
                target.status == "crafting"
                and colors.good
                or colors.border,
          }
        )

    rows[#rows + 1] =
        compose.Spacer(
          compose.Modifier
          :height(1)
        )
  end


  rows[#rows + 1] =
      compose.Spacer(
        compose.Modifier:weight(1)
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
    content = compose.Column(
      rows,
      compose.Modifier
      :fillMaxWidth()
      :fillMaxHeight()
      :padding(1)
    ),
  })
end)
