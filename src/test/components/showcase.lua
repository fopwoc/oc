local compose = require("lib.compose.init")
local components = require("lib.components.init")

local colors = components.ColorStyle()

local function paletteText(value, foreground, modifier)
  modifier = modifier or compose.Modifier

  return compose.Text(
    value,
    modifier:foreground(
      foreground or colors.text
    )
  )
end

local function page(children)
  local scrollState =
      compose.rememberScrollState()

  return compose.Column(
    children,
    compose.Modifier
    :fillMaxWidth()
    :verticalScroll(scrollState)
  )
end

local function section(title, children)
  local content = {
    compose.Text(
      title,
      compose.Modifier:foreground(colors.primary)
    ),

    compose.Spacer(
      compose.Modifier:height(1)
    ),
  }

  for _, child in ipairs(children) do
    content[#content + 1] = child
  end

  return components.Card(
    content,
    compose.Modifier:fillMaxWidth()
  )
end

compose.App(function()
  local showDialog =
      compose.remember(false)

  local clicks =
      compose.remember(0)

  local function open(context, route)
    context.navigate(route)
  end

  local function galleryPage(_, context)
    local entries = {
      {
        route = "cards",
        title = "Cards",
        description = "Borders, surfaces, padding, and widths",
      },
      {
        route = "buttons",
        title = "Buttons",
        description = "Clickable actions and visual emphasis",
      },
      {
        route = "toggles",
        title = "Toggles",
        description = "Checkboxes, switches, radios, and status",
      },
      {
        route = "dialogs",
        title = "Dialogs",
        description = "Scrim, modal barrier, and actions",
      },
      {
        route = "grid",
        title = "Grid",
        description = "Rows, cells, borders, surfaces, and empty space",
      },
      {
        route = "charts",
        title = "Charts",
        description = "Progress, bars, and filled area history",
      },
      {
        route = "accordion",
        title = "Accordion",
        description = "Collapsible content and bounded live buffers",
      },
    }

    local children = {
      compose.Text(
        "Component Gallery",
        compose.Modifier:foreground(colors.primary)
      ),

      compose.Text(
        "Select a component to inspect its variants.",
        compose.Modifier:foreground(colors.muted)
      ),

      compose.Spacer(
        compose.Modifier:height(1)
      ),
    }

    for _, entry in ipairs(entries) do
      local route = entry.route

      children[#children + 1] =
          components.Card(
            {
              compose.Row({
                compose.Text(
                  entry.title,
                  compose.Modifier
                  :foreground(colors.text)
                ),

                compose.Spacer(
                  compose.Modifier:weight(1)
                ),

                compose.Text(
                  "OPEN",
                  compose.Modifier
                  :foreground(colors.primary)
                ),
              }),

              compose.Text(
                entry.description,
                compose.Modifier
                :foreground(colors.muted)
              ),
            },
            compose.Modifier
            :fillMaxWidth()
              :clickable(
              function()
                open(context, route)
              end
            )
          )

      children[#children + 1] =
          compose.Spacer(
            compose.Modifier:height(1)
          )
    end

    return page(children)
  end

  local function cardsPage()
    return page({
      section("Card Variants", {
        components.Card({paletteText("Normal")}),

        compose.Spacer(compose.Modifier:height(1)),

        components.Card(
          {paletteText("Rounded")},
          nil,
          {
            characters = {
              topLeft = "╭",
              top = "─",
              topRight = "╮",
              right = "│",
              bottomRight = "╯",
              bottom = "─",
              bottomLeft = "╰",
              left = "│",
            },
          }
        ),

        compose.Spacer(compose.Modifier:height(1)),

        components.Card(
          {paletteText("Heavy")},
          nil,
          {
            characters = {
              topLeft = "┏",
              top = "━",
              topRight = "┓",
              right = "┃",
              bottomRight = "┛",
              bottom = "━",
              bottomLeft = "┗",
              left = "┃",
            },
          }
        ),

        compose.Spacer(compose.Modifier:height(1)),

        components.Card(
          {paletteText("ASCII")},
          nil,
          {characters = "*"}
        ),
      }),

      compose.Spacer(compose.Modifier:height(1)),

      section("Width", {
        components.Card(
          {paletteText("Full-width surface")},
          compose.Modifier:fillMaxWidth()
        ),
      }),
    })
  end

  local function buttonsPage()
    return page({
      section("Button Variants", {
        components.Button(
          "Primary action",
          function()
            clicks.value = clicks.value + 1
          end,
          compose.Modifier:foreground(colors.primary)
        ),

        compose.Text(
          "Activated: " .. tostring(clicks.value),
          compose.Modifier:foreground(colors.muted)
        ),

        compose.Spacer(compose.Modifier:height(1)),

        components.Button(
          "Warning action",
          function()
            clicks.value = clicks.value + 1
          end,
          compose.Modifier:foreground(colors.warning)
        ),

        components.Button(
          "Disabled-looking label",
          function()
          end,
          compose.Modifier:foreground(colors.muted)
        ),

        compose.Spacer(compose.Modifier:height(1)),

        components.Button(
          "Cell button",
          function()
            clicks.value = clicks.value + 1
          end,
          nil,
          components.ButtonStyles.cell
        ),
      }),
    })
  end

  local function togglesPage()
    local checkbox = compose.remember(false)
    local switch = compose.remember(true)
    local selected = compose.remember("a")
    local online = compose.remember(true)

    return page({
      section("Toggle Variants", {
        components.Toggle(
          "Checkbox",
          checkbox.value,
          function(value)
            checkbox.value = value
          end
        ),

        components.Toggle(
          "Switch",
          switch.value,
          function(value)
            switch.value = value
          end,
          components.ToggleStyles.switch
        ),

        compose.Spacer(compose.Modifier:height(1)),

        paletteText("Radio"),

        components.Toggle(
          "Option A",
          selected.value == "a",
          function()
            selected.value = "a"
          end,
          components.ToggleStyles.radio
        ),

        components.Toggle(
          "Option B",
          selected.value == "b",
          function()
            selected.value = "b"
          end,
          components.ToggleStyles.radio
        ),

        components.Toggle(
          "Option C",
          selected.value == "c",
          function()
            selected.value = "c"
          end,
          components.ToggleStyles.radio
        ),

        compose.Spacer(compose.Modifier:height(1)),

        components.Toggle(
          "Machine online",
          online.value,
          nil,
          components.ToggleStyles.status
        ),

        components.Button(
          "Toggle machine",
          function()
            online.value = not online.value
          end
        ),
      }),
    })
  end

  local function dialogsPage()
    return page({
      section("Dialog Variants", {
        paletteText(
          "Dialogs occupy the overlay layer and block input below.",
          colors.muted
        ),

        compose.Spacer(compose.Modifier:height(1)),

        components.Button(
          "Open warning dialog",
          function()
            showDialog.value = true
          end,
          compose.Modifier:foreground(colors.warning)
        ),
      }),
    })
  end

  local function gridPage()
    local rows = {
      {"Target", "Progress", "State"},
      {"long title", "1/2", "ON"},
      {"really long title that still fits", "228/228", "OFF"},
      {"transmitting", "50/600", "BUSY"},
    }

    local columns = {
      {
        weight = 1,
        align = "left",
      },
      {
        width = 9,
        align = "right",
      },
      {
        width = 7,
        align = "right",
      },
    }

    local function headerCell(value, row)
      return compose.Text(
        tostring(value or ""),
        row == 1
        and compose.Modifier:foreground(colors.primary)
        or compose.Modifier:foreground(colors.text)
      )
    end

    return page({
      section("Visible Borders", {
        components.Grid({
          rows = rows,
          columns = columns,
          appearance = "border",
          cellPadding = 0,
          cell = headerCell,
        }),
      }),

      compose.Spacer(compose.Modifier:height(1)),

      section("Alternating / Compact", {
        components.Grid({
          rows = rows,
          columns = columns,
          appearance = "alternating",
          cellPadding = 0,
          oddBackground = colors.surface,
          evenBackground = colors.surfaceVariant,
          cell = headerCell,
        }),
      }),

      compose.Spacer(compose.Modifier:height(1)),

      section("None", {
        components.Grid({
          rows = rows,
          columns = columns,
          appearance = "none",
          cellPadding = 0,
          cell = headerCell,
        }),
      }),

      compose.Spacer(compose.Modifier:height(1)),

      section("Weighted Compact", {
        components.Grid({
          rows = {
            {"Target", "Progress", "State"},
            {"Naquadah", "29/285", "READY"},
            {"Transmitting", "50/600", "BUSY"},
            {"Shadow Metal", "0/228", "IDLE"},
          },
          columns = {
            {weight = 2, align = "left"},
            {weight = 1, align = "right"},
            {weight = 1, align = "right"},
          },
          appearance = "none",
          cellPadding = 0,
          cell = headerCell,
        }),
      }),

      compose.Spacer(compose.Modifier:height(1)),

      section("Alignment", {
        components.Grid({
          rows = {
            {"Left", "Center", "Right"},
            {"alpha", "beta", "gamma"},
          },
          columns = {
            {weight = 1, align = "left"},
            {weight = 1, align = "center"},
            {weight = 1, align = "right"},
          },
          appearance = "border",
          cellPadding = 0,
          cell = headerCell,
        }),
      }),
    })
  end

  local function chartsPage()
    return page({
      section("Progress Variants", {
        compose.Text(
          "Tile backgrounds without fill characters.",
          compose.Modifier:foreground(colors.muted)
        ),

        compose.Spacer(compose.Modifier:height(1)),

        components.Progress({
          value = 0.69,
          label = true,
          labelContrast = true,
          modifier = compose.Modifier:fillMaxWidth(),
          fillColor = colors.primary,
          emptyColor = colors.surface,
        }),

        compose.Spacer(compose.Modifier:height(1)),

        components.Progress({
          value = 0.42,
          label = false,
          modifier = compose.Modifier:fillMaxWidth(),
          fillColor = colors.warning,
          emptyColor = colors.surface,
        }),

        compose.Spacer(compose.Modifier:height(1)),

        components.Progress({
          value = 0.81,
          label = "ACTIVE",
          labelContrast = true,
          labelColor = colors.warning,
          modifier = compose.Modifier:fillMaxWidth(),
          fillColor = colors.good,
          emptyColor = colors.surface,
        }),

        compose.Spacer(compose.Modifier:height(1)),

        compose.Row({
            components.Progress({
              value = 0.35,
              orientation = "vertical",
              label = true,
              labelContrast = true,
              width = 7,
              height = 6,
              fillColor = colors.good,
              emptyColor = colors.surface,
            }),

            compose.Spacer(
              compose.Modifier:width(2)
            ),

            components.Progress({
              value = 0.82,
              orientation = "vertical",
              label = true,
              labelContrast = true,
              width = 7,
              height = 6,
              fillColor = colors.warning,
              emptyColor = colors.surface,
            }),
          }),
      }),

      compose.Spacer(compose.Modifier:height(1)),

      section("Percentage Labels", {
        components.BarChart({
          rows = {
            {
              label = "CRAFTING",
              value = 0.69,
              color = colors.primary,
            },
            {
              label = "WAITING",
              value = 0.32,
              color = colors.warning,
            },
            {
              label = "COOLDOWN",
              value = 0.08,
              color = colors.muted,
            },
          },
          labelWidth = 10,
          labelContrast = true,
          fillColor = colors.primary,
          emptyColor = colors.surface,
          modifier = compose.Modifier:fillMaxWidth(),
        }),
      }),

      compose.Spacer(compose.Modifier:height(1)),

      section("Without Labels", {
        components.BarChart({
          rows = {
            {label = "A", value = 0.85},
            {label = "B", value = 0.55},
            {label = "C", value = 0.25},
          },
          labelWidth = 2,
          showLabels = false,
          fillColor = colors.good,
          emptyColor = colors.surface,
          modifier = compose.Modifier:fillMaxWidth(),
        }),
      }),

      compose.Spacer(compose.Modifier:height(1)),

      section("Filled History", {
        components.AreaChart({
          values = {
            0.18, 0.32, 0.27, 0.48, 0.42, 0.66,
            0.58, 0.76, 0.61, 0.84, 0.72, 0.92,
          },
          height = 7,
          fillColor = colors.primary,
          emptyColor = colors.surface,
          modifier = compose.Modifier:fillMaxWidth(),
        }),
      }),

      compose.Spacer(compose.Modifier:height(1)),

      section("Grouped Columns", {
        components.AreaChart({
          values = {
            0.25, 0.5, 0.35, 0.7, 0.55, 0.85,
          },
          height = 6,
          barWidth = 2,
          gap = 1,
          fillColor = colors.warning,
          emptyColor = colors.surface,
          modifier = compose.Modifier:fillMaxWidth(),
        }),
      }),
    })
  end

  local function accordionPage()
    local buffer =
        compose.rememberRingBuffer(24)

    compose.LaunchedEffect("buffer-preview", function()
      local sequence = 0

      while true do
        sequence = sequence + 1

        buffer:push(
          string.format(
            "event %02d  stream update received",
            sequence
          )
        )

        compose.delay(1)
      end
    end)

    return page({
      section("Accordion Variants", {
        components.Accordion({
          key = "live-stream",
          title = "Live stream",
          initiallyExpanded = true,
          headerModifier = compose.Modifier
            :foreground(colors.primary),
          content = function()
            return components.BufferView({
              buffer = buffer,
              empty = paletteText(
                "Waiting for updates...",
                colors.muted
              ),
              modifier = compose.Modifier
                :height(5)
                :fillMaxWidth()
                :border(colors.muted)
                :background(colors.surface),
              item = function(value)
                return paletteText(value)
              end,
            })
          end,
        }),

        compose.Spacer(compose.Modifier:height(1)),

        components.Accordion({
          key = "implementation-notes",
          title = "Implementation notes",
          headerModifier = compose.Modifier
            :foreground(colors.muted),
          content = function()
            return compose.Column({
              paletteText("Fixed capacity: 24 records"),
              paletteText("Oldest records are overwritten"),
              paletteText("Hidden content is not rendered"),
            })
          end,
        }),
      }),
    })
  end

  local pages = {
    gallery = galleryPage,
    cards = cardsPage,
    buttons = buttonsPage,
    toggles = togglesPage,
    dialogs = dialogsPage,
    grid = gridPage,
    charts = chartsPage,
    accordion = accordionPage,
  }

  local hints = {}

  return components.Entrypoint({
    start = "gallery",
    title = "Components",
    colorStyle = colors,
    routes = pages,
    hints = hints,
    service = "select a component",
    overlay = function()
      if not showDialog.value then
        return nil
      end

      return components.Dialog(
        "WARNING",
        {
          paletteText("LCR #4 is not responding."),
          paletteText("Underlying controls are blocked."),
          compose.Spacer(compose.Modifier:height(1)),
          compose.Row({
            components.Button(
              "IGNORE",
              function()
                showDialog.value = false
              end
            ),

            compose.Spacer(compose.Modifier:width(2)),

            components.Button(
              "RETRY",
              function()
                clicks.value = clicks.value + 1
                showDialog.value = false
              end
            ),
          }),
        },
        compose.Modifier
        :width(40)
        :background(colors.badContainer)
      )
    end,
  })
end)
