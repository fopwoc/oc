package.loaded["../lib/compose/init"] = nil
package.loaded["../lib/compose/runtime"] = nil
package.loaded["../lib/compose/nodes"] = nil
package.loaded["../lib/compose/renderer"] = nil
package.loaded["../lib/compose/framebuffer"] = nil
package.loaded["../lib/compose/debug"] = nil
package.loaded["../lib/compose/modifier"] = nil
package.loaded["../lib/compose/layout"] = nil
package.loaded["../lib/compose/input"] = nil
package.loaded["../lib/compose/hit_test"] = nil
package.loaded["../lib/compose/scroll"] = nil

local compose = require("../lib/compose/init")

compose.App(function()
  local progress = compose.remember(0)
  local clicks = compose.remember(0)
  local scroll = compose.remember(0)

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
        compose.Text("COMPOSE SHOWCASE"),

        compose.Text(
          "ASCII | Кириллица | 日本語 | 😀 🚀 ❤️"
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
            "Progress: "
              .. math.floor(
                progress.value * 100
              )
              .. "%"
          ),

          compose.Progress(
            progress.value,
            compose.Modifier:fillMaxWidth()
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
          })
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
