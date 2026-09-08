local compose = require("lib.compose.init")
local components = require("lib.components.init")
local debug = require("lib.compose.debug")

compose.App(function()
  local progress = compose.remember(0)
  local clicks = compose.remember(0)
  local scroll = compose.remember(0)
  local mouseEvent = compose.remember("none")
  local mouseDetails = compose.remember("waiting for touch / drag / drop")
  local debugEnabled = compose.remember(debug.isEnabled())

  local function observeMouseEvent(name)
    compose.LaunchedEffect(
      "mouse-probe-" .. name,
      function()
        while true do
          local _, screen, x, y, button, player =
              compose.awaitEvent(name)

          mouseEvent.value = name
          mouseDetails.value =
              string.format(
                "x %d y %d button %s",
                x,
                y,
                tostring(button)
              )
        end
      end
    )
  end

  observeMouseEvent("touch")
  observeMouseEvent("drag")
  observeMouseEvent("drop")

  local lifecycleVisible =
      compose.remember(true)

  local lifecycleTicks =
      compose.remember(0)

  local effectKey =
      compose.remember(1)

  local keyTicks =
      compose.remember(0)

  compose.LaunchedEffect("progress", function()
    while true do
      progress.value = math.random()
      compose.delay(1)
    end
  end)

  return compose.Column({
    --
    -- Header / Unicode / layout
    --

    compose.RecomposeScope("static", function()
      return compose.Column({
          compose.Row({
              compose.Text("COMPOSE SHOWCASE"),

              compose.Spacer(
                compose.Modifier:weight(1)
              ),

              components.Toggle(
                "RECOMPOSE DEBUG",
                debugEnabled.value,
                function(enabled)
                  debug.setEnabled(enabled)
                  debugEnabled.value = enabled
                end,
                components.ToggleStyles.switch
              ),
            },
            compose.Modifier:fillMaxWidth()
          ),

          compose.Text(
            "ASCII | Кириллица | 日本語 | 😀 🚀 ❤️",
            compose.Modifier
            :border()
          ),

          compose.Row({
              compose.Text(
                "LCR #4",
                compose.Modifier:align(nil, "center")
              ),

              compose.Spacer(
                compose.Modifier:weight(1)
              ),

              compose.Text(
                "RUNNING",
                compose.Modifier:align(nil, "bottom")
              ),
            },
            compose.Modifier
            :fillMaxWidth()
            :height(3)
            :border()
          ),
        },
        compose.Modifier
        :border()
        :padding(1)
      )
    end),

    --
    -- State / input / effects
    --

    compose.Row({
        compose.RecomposeScope("progress", function()
          return compose.Column({
              compose.Text("STATE / EFFECT"),

              compose.Text(
                "Random value: "
                .. math.floor(
                  progress.value * 100
                )
                .. "%"
              ),

            },
            compose.Modifier
            :weight(1)
            :padding(1)
            :border()
          )
        end),

        compose.RecomposeScope("clicks", function()
          return compose.Column({
              compose.Text("INPUT"),

              compose.Text(
                "[ Click me ]",
                compose.Modifier
                :clickable(function()
                  clicks.value =
                      clicks.value + 1
                end)
              ),

              compose.Text(
                "Clicks: " .. clicks.value
              ),
            },
            compose.Modifier
            :weight(1)
            :padding(1)
            :border()
          )
        end),

        compose.RecomposeScope("scroll", function()
          return compose.Column({
              compose.Text("SCROLL"),

              compose.Text(
                "Value: " .. scroll.value
              ),

              compose.Text(
                "Scroll here"
              ),
            },
            compose.Modifier
            :weight(1)
            :padding(1)
            :border()
            :scrollable(function(direction)
              scroll.value =
                  scroll.value + direction
            end)
          )
        end),

        compose.RecomposeScope("mouseProbe", function()
          return compose.Column({
              compose.Text("MOUSE EVENTS"),

              components.EventConsumer({
                onClick = function(event)
                    mouseEvent.value = "handled touch"
                    mouseDetails.value =
                        string.format(
                          "x %d y %d button %s",
                          event.screenX,
                          event.screenY,
                          tostring(event.button)
                        )
                  end,

                content = function(state)
                  local background =
                      state.pressed
                      and 0x6BD5FF
                      or 0x245A73

                  local foreground =
                      state.pressed
                      and 0x101418
                      or 0xFFFFFF

                  return compose.Box({
                      compose.Text(
                        "Touch target",
                        compose.Modifier:foreground(
                          foreground
                        )
                      ),
                    },
                    state.modifier
                    :padding(1)
                    :background(background)
                  )
                end,
              }),

              compose.Text(
                "Last: " .. mouseEvent.value
              ),

              compose.Text(mouseDetails.value),
            },
            compose.Modifier
            :weight(1)
            :padding(1)
            :border()
          )
        end),
      },
      compose.Modifier
      :fillMaxWidth()
    ),

    --
    -- Effect lifecycle tests
    --

    compose.Row({
        compose.Column({
            compose.Text("LIFECYCLE"),

            compose.Text(
              lifecycleVisible.value
              and "[ Hide effect ]"
              or "[ Show effect ]",

              compose.Modifier
              :clickable(function()
                lifecycleVisible.value =
                    not lifecycleVisible.value
              end)
            ),

            lifecycleVisible.value
            and compose.RecomposeScope(
              "lifecycle-test",
              function()
                compose.LaunchedEffect(
                  "ticker",
                  function()
                    while true do
                      compose.delay(1)

                      lifecycleTicks.value =
                          lifecycleTicks.value + 1
                    end
                  end
                )

                return compose.Text(
                  "Ticks: "
                  .. lifecycleTicks.value
                )
              end
            )
            or compose.Text(
              "Stopped: "
              .. lifecycleTicks.value
            ),
          },
          compose.Modifier
          :weight(1)
          :padding(1)
          :border()
        ),

        compose.RecomposeScope(
          "effect-key-test",
          function()
            local key =
                effectKey.value

            compose.LaunchedEffect(
              key,
              function()
                while true do
                  compose.delay(1)

                  keyTicks.value =
                      keyTicks.value + 1
                end
              end
            )

            return compose.Column({
              compose.Text("EFFECT KEY"),

              compose.Text(
                "[ Key: "
                .. key
                .. " ]",

                compose.Modifier
                :clickable(function()
                  effectKey.value =
                      effectKey.value + 1
                end)
              ),

              compose.Text(
                "Ticks: "
                .. keyTicks.value
              ),
            },
            compose.Modifier
            :weight(1)
            :padding(1)
            :border()
          )
          end
        ),
      },
      compose.Modifier
      :fillMaxWidth()
    ),

    --
    -- Alignment / Box / Spacer
    --

    compose.Row({
        compose.Column({
            compose.Text("left"),

            compose.Text(
              "center",
              compose.Modifier:align("center")
            ),

            compose.Text(
              "right",
              compose.Modifier:align("right")
            ),
          },
          compose.Modifier
          :weight(1)
          :border()
        ),

        compose.Box({
            compose.Text(
              "Inside Box",
              compose.Modifier:align(
                "center",
                "center"
              )
            ),
          },
          compose.Modifier
          :weight(1)
          :height(5)
          :background(0x222222)
        ),

        compose.Column({
            compose.Text("Spacer"),

            compose.Spacer(
              compose.Modifier:height(1)
            ),

            compose.Text("After"),
          },
          compose.Modifier
          :weight(1)
          :border()
        ),
      },
      compose.Modifier
      :fillMaxWidth()
    ),

    --
    -- Color / alpha compositing
    --

    compose.RecomposeScope(
      "color-mixing",
      function()
        local red =
            compose.Color(0xFF0000, 0.55)

        local green =
            compose.Color(0x00FF00, 0.55)

        local blue =
            compose.Color(0x0000FF, 0.55)

        local function swatch(label, color)
          return compose.Box({
              compose.Text(
                label,
                compose.Modifier:align(
                  "center",
                  "center"
                )
              ),
            },
            compose.Modifier
            :width(5)
            :height(3)
            :border()
            :background(color)
          )
        end

        local function swatches(title, alpha)
          return compose.Column({
              compose.Text(title),

              compose.Row({
                  swatch("R", compose.Color(0xFF0000, alpha)),
                  swatch("G", compose.Color(0x00FF00, alpha)),
                  swatch("B", compose.Color(0x0000FF, alpha)),
                }),
            },
            compose.Modifier
          )
        end

        local function square(label, color, x)
          return compose.Box({
              compose.Text(
                label,
                compose.Modifier:align(
                  "center",
                  "center"
                )
              ),
            },
            compose.Modifier
            :width(9)
            :height(3)
            :background(color)
            :offset(x, 0)
          )
        end

        return compose.Column({
            compose.Row({
                swatches("OPAQUE / 1", 1),
                compose.Spacer(compose.Modifier:width(4)),
                swatches("CLEAR / 0", 0),
                compose.Spacer(compose.Modifier:width(4)),
                swatches("PLAIN / .5", 0.5),
                compose.Spacer(compose.Modifier:width(4)),

                compose.Column({
                    compose.Text("OVERLAP / .55"),

                    compose.Box({
                        square("R", red, 0),
                        square("G", green, 3),
                        square("B", blue, 6),
                      },
                      compose.Modifier
                      :width(15)
                      :height(3)
                    ),
                  }),
                compose.Spacer(compose.Modifier:width(4)),

                compose.Column({
                    compose.Text("ON WHITE"),

                    compose.Box({
                        square("R", red, 0),
                        square("G", green, 3),
                        square("B", blue, 6),
                      },
                      compose.Modifier
                      :width(15)
                      :height(3)
                      :background(0xFFFFFF)
                    ),
                  }),
                compose.Spacer(compose.Modifier:width(4)),

                compose.Column({
                    compose.Text("SCRIM / .5"),

                    compose.Box({
                        compose.Text(
                          "DEFAULT WHITE",
                          compose.Modifier:align(
                            "center",
                            "center"
                          )
                        ),

                        compose.Box({},
                          compose.Modifier
                          :fillMaxWidth()
                          :fillMaxHeight()
                          :scrim(0xFF0000, 0.5)
                        ),
                      },
                      compose.Modifier
                      :width(15)
                      :height(3)
                      :background(0x0000FF)
                    ),
                  }),
                compose.Spacer(compose.Modifier:width(4)),

                compose.Column({
                    compose.Text("TEXT / .25"),

                    compose.Box({
                        compose.Text(
                          "WHITE .25",
                          compose.Modifier
                          :align("center", "center")
                          :foreground(
                            compose.Color(
                              0xFFFFFF,
                              0.25
                            )
                          )
                        ),
                      },
                      compose.Modifier
                      :width(15)
                      :height(3)
                      :background(0x003366)
                    ),
                  }),
                compose.Spacer(compose.Modifier:width(4)),

                compose.Column({
                    compose.Text("CONTRAST"),

                    compose.Box({
                        compose.Row({
                            compose.Box({},
                              compose.Modifier
                              :weight(1)
                              :fillMaxHeight()
                              :background(0x000000)
                            ),

                            compose.Box({},
                              compose.Modifier
                              :weight(1)
                              :fillMaxHeight()
                              :background(0xFFFFFF)
                            ),
                          },
                          compose.Modifier
                          :fillMaxWidth()
                          :fillMaxHeight()
                        ),

                        compose.Text(
                          "CONTRAST",
                          compose.Modifier
                          :align("center", "center")
                          :foreground(0xFFFFFF)
                          :autoContrast()
                        ),
                      },
                      compose.Modifier
                      :width(18)
                      :height(3)
                    ),
                  }),
              },
              compose.Modifier:fillMaxWidth()
            ),
          },
          compose.Modifier
          :fillMaxWidth()
          :padding(1)
          :border()
        )
      end
    ),

    --
    -- Vertical scroll
    --

    compose.RecomposeScope(
      "verticalScroll",
      function()
        local scrollState =
            compose.rememberScrollState()

        local children = {
          compose.Text(
            "VERTICAL SCROLL"
          ),
        }

        for i = 1, 30 do
          local index = i

          children[#children + 1] =
              compose.RecomposeScope(
                "scrollItem" .. index,
                function()
                  local clicks =
                      compose.remember(0)

                  return compose.Text(
                    "Item "
                    .. index
                    .. " clicks: "
                    .. clicks.value,

                    compose.Modifier
                    :fillMaxWidth()
                    :clickable(function()
                      clicks.value =
                          clicks.value + 1
                    end)
                  )
                end
              )
        end

        return compose.Column(
          children,
          compose.Modifier
          :fillMaxWidth()
          :height(8)
          :verticalScroll(scrollState)
          :border()
        )
      end
    ),

    compose.RecomposeScope(
      "footer",
      function()
        return compose.Text(
          "Press Q to exit"
        )
      end
    ),
  })
end)
