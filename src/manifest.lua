return {
  compose = {
    depends = {
      "coroutines",
      "collections",
    },
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
      "lib/compose/hardware.lua",
    },
  },

  coroutines = {
    files = {
      "lib/coroutines.lua",
    },
  },

  test_suite = {
    depends = {
      "ae2_craftable",
      "compose",
      "telemetry_incidents",
      "telemetry_store",
      "storage",
      "power_monitor_core",
      "production_line",
      "collections",
      "query",
      "timeline",
      "utils",
    },
    files = {
      "test/suite.lua",
      "test/compose.lua",
      "test/coroutines.lua",
      "test/coroutines/scheduler.lua",
      "test/compose/engine.lua",
      "test/compose/color.lua",
      "test/compose/color_math.lua",
      "test/compose/framebuffer.lua",
      "test/compose/ring_buffer.lua",
      "test/compose/navigation_engine.lua",
      "test/compose/lifecycle.lua",
      "test/compose/renderer.lua",
      "test/storage.lua",
      "test/storage/round_trip.lua",
      "test/storage/footprint.lua",
      "test/telemetry.lua",
      "test/telemetry/incident_manager.lua",
      "test/telemetry/incidents.lua",
      "test/telemetry/store.lua",
      "test/crafter.lua",
      "test/crafter/fluid.lua",
      "test/collections.lua",
      "test/collections/rolling_counter.lua",
      "test/format.lua",
      "test/series.lua",
      "test/clock.lua",
      "test/query.lua",
      "test/power_monitor/chart.lua",
      "test/production_line/chart.lua",
      "test/timeline.lua",
    },
    run = "test/suite.lua",
    description = "Core regression tests",
  },

  test_scaffold = {
    depends = {
      "compose_components",
    },
    files = {
      "test/scaffold.lua",
      "test/components/scaffold.lua",
    },
    run = "test/scaffold.lua",
    description = "Scaffold input handling test",
  },

  test_suite_adapter = {
    depends = {
      "ae2_craftable",
      "ae2_network",
      "gt_lapotronic",
    },
    files = {
      "test/suite_adapter.lua",
      "test/production_line.lua",
      "test/production_line/ae2.lua",
      "test/crafter/adapter.lua",
      "test/crafter/fluid_adapter.lua",
      "test/power_monitor.lua",
      "test/power_monitor/adapter.lua",
      "test/power_monitor/component.lua",
    },
    run = "test/suite_adapter.lua",
    description = "Read-only OpenComputers adapter API checks",
  },

  ae2_craftable = {
    files = {
      "lib/ae2/craftable.lua",
    },
  },

  ae2_network = {
    files = {
      "lib/ae2/network.lua",
    },
  },

  query = {
    depends = {
      "ae2_network",
    },
    files = {
      "lib/ae2/query.lua",
      "script/query.lua",
    },
    run = "script/query.lua",
    description = "Search the connected AE2 network",
  },

  gt_lapotronic = {
    files = {
      "lib/gt/lapotronic.lua",
    },
  },

  compose_components = {
    depends = {
      "compose",
      "utils",
    },
    files = {
      "lib/components/init.lua",
      "lib/components/card.lua",
      "lib/components/button.lua",
      "lib/components/event_consumer.lua",
      "lib/components/toggle.lua",
      "lib/components/dialog.lua",
      "lib/components/scaffold.lua",
      "lib/components/top_app_bar.lua",
      "lib/components/command_bar.lua",
      "lib/components/grid.lua",
      "lib/components/entrypoint.lua",
      "lib/components/color_style.lua",
      "lib/components/accordion.lua",
      "lib/components/buffer_view.lua",
      "lib/components/progress.lua",
      "lib/components/bar_chart.lua",
      "lib/components/area_chart.lua",
      "lib/components/section.lua",
      "lib/components/telemetry_status.lua",
    },
  },

  test_compose = {
    depends = {
      "compose_components",
    },
    files = {
      "test/compose_showcase.lua",
      "test/components/compose.lua",
    },
    run = "test/compose_showcase.lua",
    description = "UI showcase",
  },

  test_scroll = {
    depends = {
      "compose",
    },
    files = {
      "test/scroll.lua",
      "test/components/scroll.lua",
    },
    run = "test/scroll.lua",
    description = "Scroll and recomposition stress test",
  },

  test_components = {
    depends = {
      "compose_components"
    },
    files = {
      "test/components.lua",
      "test/components/showcase.lua",
    },
    run = "test/components.lua",
    description = "Components showcase",
  },

    test_unicode = {
    files = {
      "test/unicode.lua",
      "test/components/unicode.lua",
    },
    run = "test/unicode.lua",
      description = "unicode test",
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
      "test/components/navigation.lua",
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

  telemetry_store = {
    files = {
      "lib/telemetry/store.lua",
    },
  },

  storage = {
    files = {
      "lib/storage/store.lua",
    },
  },

  telemetry_incidents = {
    depends = {
      "telemetry_sender",
    },
    files = {
      "lib/telemetry/incidents/manager.lua",
      "lib/telemetry/incidents/dashboard.lua",
    },
  },

  utils = {
    files = {
      "lib/utils/clock.lua",
      "lib/utils/decimal.lua",
      "lib/utils/format.lua",
      "lib/utils/series.lua",
    },
  },

  timeline = {
    depends = {
      "collections",
    },
    files = {
      "lib/timeline.lua",
    },
  },

  collections = {
    files = {
      "lib/collections/ring_buffer.lua",
      "lib/collections/rolling_counter.lua",
    },
  },

  config_loader = {
    files = {
      "lib/config/loader.lua",
    },
  },

  production_line = {
    depends = {
      "timeline",
    },
    files = {
      "lib/production_line/analytics.lua",
    },
  },

  power_monitor_core = {
    depends = {
      "collections",
      "timeline",
      "utils",
    },
    files = {
      "lib/power_monitor/analytics.lua",
    },
  },

  power_monitor = {
    depends = {
      "compose_components",
      "config_loader",
      "power_monitor_core",
      "gt_lapotronic",
      "storage",
      "telemetry_sender",
      "utils",
    },
    files = {
      "app/power_monitor/config.example.lua",
      "app/power_monitor/main.lua",
      "app/power_monitor/settings.lua",
    },
    run = "app/power_monitor/main.lua",
    description = "GTNH power sustainability monitor",
  },

  line_monitor = {
    depends = {
      "ae2_network",
      "compose_components",
      "config_loader",
      "telemetry_incidents",
      "utils",
      "telemetry_sender",
      "production_line",
    },
    files = {
      "app/line_monitor/config.example.lua",
      "app/line_monitor/config.example_hog.lua",
      "app/line_monitor/main.lua",
    },
    run = "app/line_monitor/main.lua",
    description = "Passive AE2 production line monitor",
  },

  crafter = {
    depends = {
      "ae2_craftable",
      "compose_components",
      "config_loader",
      "ae2_network",
      "telemetry_sender",
      "collections",
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
      "storage",
      "telemetry_incidents",
      "telemetry_receiver",
      "telemetry_store",
      "utils",
    },
    files = {
      "app/dashboard/main.lua",
      "app/dashboard/presenter.lua",
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
