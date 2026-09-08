local compose = require("lib.compose.init")

local components = require("lib.components.init")

local telemetry = require("lib.telemetry.receiver")
local telemetryStore = require("lib.telemetry.store")
local incidentDashboard = require("lib.telemetry.incidents.dashboard")
local incidentHistory = require("app.dashboard.incident_history")

local presenter = require("app.dashboard.presenter")


local colors = components.ColorStyle()


local receiver =
    telemetry.create()

local dashboard =
    telemetryStore.create()

local incidents =
    incidentDashboard.create({
      history = incidentHistory.create(),
    })

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
          local incidentChanged =
              incidents:handle(packet)

          if packet.event == "telemetry" then
            dashboard:update(packet)
          end

          if incidentChanged
              or packet.event == "telemetry"
          then
            revision.value =
                revision.value + 1
          end
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

  local sections =
      presenter.sections(
        sources,
        dashboard,
        colors
      )

  local content = {}

  for _, section in ipairs(sections) do
    content[#content + 1] = compose.Text(
      section.title,
      compose.Modifier:foreground(colors.primary)
    )

    content[#content + 1] = components.Grid({
      rows = section.rows,
      columns = section.columns,
      appearance = "alternating",
      oddBackground = colors.background,
      evenBackground = colors.surface,
      cellPadding = 0,
      cell = section.cell,
      modifier = compose.Modifier:fillMaxWidth(),
    })

    content[#content + 1] = compose.Spacer(
      compose.Modifier:height(1)
    )
  end

  if #content == 0 then
    content[#content + 1] = compose.Text(
      "WAITING FOR TELEMETRY",
      compose.Modifier:foreground(colors.muted)
    )
  end

  local scrollState =
      compose.rememberScrollState()

  local currentIncident =
      incidents:current()

  local activeIncidentCount =
      incidents:activeCount()


  return components.Entrypoint({
    title = "Dashboard",
    service = "Telemetry :4242",
    topBarActions = function()
      return compose.Row({
        compose.Text(
          tostring(#sources) .. " SOURCES",
          compose.Modifier:foreground(colors.muted)
        ),
        compose.Spacer(compose.Modifier:width(1)),
        compose.Text(
          "INCIDENTS " .. tostring(activeIncidentCount),
          compose.Modifier:foreground(
            activeIncidentCount > 0
              and colors.bad
              or colors.muted
          )
        ),
      })
    end,
    overlay = function()
      if not currentIncident then
        return nil
      end

      return components.Dialog(
        "INCIDENT",
        {
          compose.Text(
            currentIncident.title,
            compose.Modifier:foreground(colors.onSurface)
          ),

          compose.Spacer(compose.Modifier:height(1)),

          compose.Text(
            currentIncident.message,
            compose.Modifier:foreground(colors.text)
          ),

          compose.Spacer(compose.Modifier:height(1)),

          compose.Text(
            currentIncident.source
              .. " · "
              .. currentIncident.sourceId,
            compose.Modifier:foreground(colors.muted)
          ),

          compose.Spacer(compose.Modifier:height(1)),

          components.Button(
            "CLOSE",
            function()
              if incidents:dismiss(currentIncident.key) then
                revision.value =
                    revision.value + 1
              end
            end,
            compose.Modifier:foreground(colors.primary)
          ),
        },
        compose.Modifier
        :width(40)
        :background(colors.surfaceVariant)
      )
    end,
    content = compose.Column(
      content,
      compose.Modifier
      :fillMaxWidth()
      :fillMaxHeight()
      :padding(1)
      :verticalScroll(scrollState)
    ),
  })
end)
