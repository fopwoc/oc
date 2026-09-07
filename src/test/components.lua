local compose = require("../lib/compose/init")
local components = require("../lib/components/init")

compose.App(function()
  local scrollState =
      compose.rememberScrollState()

  local clicks =
      compose.remember(0)

  local checkbox =
      compose.remember(false)

  local switch =
      compose.remember(true)

  local selected =
      compose.remember("a")

  local machineOnline =
      compose.remember(true)

  local showDialog =
      compose.remember(false)

  local content =
      compose.Column({
          compose.Text("COMPONENT GALLERY"),

          compose.Spacer(
            compose.Modifier:height(1)
          ),

          compose.Row({
            components.Card({
              compose.Text("Normal")
            }),

            compose.Spacer(
              compose.Modifier:width(1)
            ),

            components.Card(
              {
                compose.Text("Rounded")
              },
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
                }
              }
            ),

            compose.Spacer(
              compose.Modifier:width(1)
            ),

            components.Card(
              {
                compose.Text("Heavy")
              },
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
                }
              }
            ),

            compose.Spacer(
              compose.Modifier:width(1)
            ),

            components.Card(
              {
                compose.Text("Double")
              },
              nil,
              {
                characters = {
                  topLeft = "╔",
                  top = "═",
                  topRight = "╗",
                  right = "║",
                  bottomRight = "╝",
                  bottom = "═",
                  bottomLeft = "╚",
                  left = "║",
                }
              }
            ),
            components.Card(
              {
                compose.Text("ASCII")
              },
              nil,
              {
                characters = "*"
              }
            ),
          }),

          compose.Spacer(
            compose.Modifier:height(1)
          ),

          components.Card(
            {
              compose.Column({
                compose.Text("CARD + WIDTH"),
                compose.Text(
                  "Custom modifier"
                ),
              })
            },
            compose.Modifier
            :fillMaxWidth()
          ),

          compose.Spacer(
            compose.Modifier:height(1)
          ),

          components.Card({
            compose.Column({
              compose.Text("BUTTON"),

              components.Button(
                "Click me",
                function()
                  clicks.value =
                      clicks.value + 1
                end
              ),

              compose.Text(
                "Clicks: "
                .. clicks.value
              ),

              components.Button(
                "Open warning",
                function()
                  showDialog.value =
                      true
                end
              ),
            })
          }),

          compose.Spacer(
            compose.Modifier:height(1)
          ),

          components.Card({
            compose.Column({
              compose.Text("TOGGLE"),

              components.Toggle(
                "Checkbox",
                checkbox.value,
                function(value)
                  checkbox.value =
                      value
                end
              ),

              components.Toggle(
                "Switch",
                switch.value,
                function(value)
                  switch.value =
                      value
                end,
                components.ToggleStyles.switch
              ),

              compose.Text(""),

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
            })
          }),

          compose.Spacer(
            compose.Modifier:height(1)
          ),

          components.Card({
            compose.Column({
              compose.Text("STATUS"),

              components.Toggle(
                "LCR",
                machineOnline.value,
                nil,
                components.ToggleStyles.status
              ),

              components.Button(
                "Toggle machine",
                function()
                  machineOnline.value =
                      not machineOnline.value
                end
              ),

              components.Toggle(
                "Custom",
                machineOnline.value,
                nil,
                {
                  on = "●",
                  off = "○",
                }
              ),
            })
          }),

          compose.Spacer(
            compose.Modifier:height(1)
          ),

          components.Card({
            compose.Column({
              compose.Text("LONG CONTENT"),

              compose.Text(
                "This section exists"
              ),

              compose.Text(
                "to force fullscreen"
              ),

              compose.Text(
                "vertical scrolling."
              ),

              compose.Text(""),

              compose.Text("Line 1"),
              compose.Text("Line 2"),
              compose.Text("Line 3"),
              compose.Text("Line 4"),
              compose.Text("Line 5"),
              compose.Text("Line 6"),
              compose.Text("Line 7"),
              compose.Text("Line 8"),
              compose.Text("Line 9"),
              compose.Text("Line 10"),
            })
          }),

          compose.Spacer(
            compose.Modifier:height(1)
          ),

          compose.Text("Press Q to exit"),
        },
        compose.Modifier
        :fillMaxWidth()
        :verticalScroll(scrollState)
      )

  local children = {
    content
  }

  if showDialog.value then
    children[#children + 1] =
        components.Dialog(
          "WARNING",
          {
            compose.Text(
              "LCR #4 is not responding."
            ),

            compose.Text(
              "Underlying controls"
            ),

            compose.Text(
              "should not react."
            ),

            compose.Spacer(
              compose.Modifier:height(1)
            ),

            compose.Row({
              components.Button(
                "IGNORE",
                function()
                  showDialog.value = false
                end
              ),

              compose.Spacer(
                compose.Modifier:width(2)
              ),

              components.Button(
                "RETRY",
                function()
                  clicks.value =
                      clicks.value + 1

                  showDialog.value = false
                end
              ),
            }),
          },
          compose.Modifier
          :width(40)
          :background(0x552222),
          {
            color = 0xCC5555,
            characters = {
              topLeft = "╔",
              top = "═",
              topRight = "╗",
              right = "║",
              bottomRight = "╝",
              bottom = "═",
              bottomLeft = "╚",
              left = "║",
            }
          }
        )
  end

  return compose.Box(
    children,
    compose.Modifier
    :fillMaxWidth()
    :fillMaxHeight()
  )
end)
