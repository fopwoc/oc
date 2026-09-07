local compose = require("lib.compose.init")
local components = require("lib.components.init")

local colors = {
  background = 0x101418,
  surface = 0x1A2228,
  primary = 0x6BD5FF,
  text = 0xE2E8F0,
  muted = 0x8B96A3,
  warning = 0xE5C36A,
}

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
        components.Card({compose.Text("Normal")}),

        compose.Spacer(compose.Modifier:height(1)),

        components.Card(
          {compose.Text("Rounded")},
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
          {compose.Text("Heavy")},
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
          {compose.Text("ASCII")},
          nil,
          {characters = "*"}
        ),
      }),

      compose.Spacer(compose.Modifier:height(1)),

      section("Width", {
        components.Card(
          {compose.Text("Full-width surface")},
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

        compose.Text("Radio"),

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
        compose.Text(
          "Dialogs occupy the overlay layer and block input below."
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
          evenBackground = 0x2A343C,
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
              empty = "Waiting for updates...",
              modifier = compose.Modifier
                :height(5)
                :fillMaxWidth()
                :border(colors.muted)
                :background(colors.surface),
              item = function(value)
                return compose.Text(
                  value,
                  compose.Modifier:foreground(colors.text)
                )
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
              compose.Text("Fixed capacity: 24 records"),
              compose.Text("Oldest records are overwritten"),
              compose.Text("Hidden content is not rendered"),
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
    accordion = accordionPage,
  }

  local hints = {}

  return components.Entrypoint({
    start = "gallery",
    title = "Components",
    colors = colors,
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
          compose.Text("LCR #4 is not responding."),
          compose.Text("Underlying controls are blocked."),
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
        :background(0x552222)
      )
    end,
  })
end)
