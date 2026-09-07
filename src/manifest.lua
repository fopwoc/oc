return {
  compose = {
    files = {
      "lib/compose/nodes.lua",
      "lib/compose/runtime.lua",
      "lib/compose/host.lua",
      "lib/compose/renderer.lua",
      "lib/compose/framebuffer.lua",
      "lib/compose/init.lua",
      "lib/compose/debug.lua",
      "lib/compose/modifier.lua",
      "lib/compose/color.lua",
      "lib/compose/layout.lua",
      "lib/compose/input.lua",
      "lib/compose/input_target.lua",
      "lib/compose/scroll.lua",
      "lib/compose/navigation.lua",
    },
  },

  compose_components = {
    depends = {
      "compose",
    },
    files = {
      "lib/components/init.lua",
      "lib/components/card.lua",
      "lib/components/button.lua",
      "lib/components/toggle.lua",
      "lib/components/dialog.lua",
    },
  },

  test_compose = {
    depends = {
      "compose",
    },
    files = {
      "test/ui.lua",
    },
    run = "test/ui.lua",
    description = "UI showcase",
  },

  test_components = {
    depends = {
      "compose_components"
    },
    files = {
      "test/components.lua",
    },
    run = "test/components.lua",
    description = "Components showcase",
  },

    test_unicode = {
      files = {
        "test/unicode.lua",
    },
    run = "test/unicode.lua",
      description = "unicode test",
    },

  test_colors = {
      depends = {
        "compose",
      },
      files = {
        "test/colors.lua",
      },
      run = "test/colors.lua",
      description = "Color compositing showcase",
    },

  telemetry_protocol = {
    files = {
      "lib/telemetry/protocol.lua",
    },
  },

  test_navigation = {
    depends = {
      "compose",
    },
    files = {
      "test/navigation.lua",
    },
    run = "test/navigation.lua",
    description = "Navigation showcase",
  },

  telemetry_sender = {
    depends = {
      "telemetry_protocol",
    },
    files = {
      "lib/telemetry/sender.lua",
    },
  },

  telemetry_receiver = {
    depends = {
      "telemetry_protocol",
    },
    files = {
      "lib/telemetry/receiver.lua",
    },
  },

  crafter = {
    depends = {
      "compose_components",
      "telemetry_sender",
    },
    files = {
      "app/crafter/config.example.lua",
      "app/crafter/scheduler.lua",
      "app/crafter/main.lua",
    },
    run = "app/crafter/main.lua",
    description = "Craft Scheduler",
  },

  dashboard = {
    depends = {
      "compose_components",
      "telemetry_receiver",
    },
    files = {
      "app/dashboard/main.lua",
      "app/dashboard/state.lua",
    },
    run = "app/dashboard/main.lua",
    description = "Craft Dashboard",
  },

  rain = {
    files = {
      "script/rain.lua",
    },
    run = "script/rain.lua",
    description = "Matrix rain",
  },

  plasma = {
    depends = {
      "compose",
    },
    files = {
      "script/plasma.lua",
    },
    run = "script/plasma.lua",
    description = "Plasma",
  },
}
