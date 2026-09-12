# Architecture

This project is a small packet manager for Lua code running in OpenComputers. The packet manager distributes a manifest-defined graph of libraries, components, tests, applications, and entrypoints. One of the main distributed libraries is a declarative UI engine that borrows useful ideas behind Compose without importing a large framework or pretending that an OC screen is a modern pixel-based display.

The target is a character framebuffer with expensive GPU calls, limited Lua memory, and a slow event-driven computer. That makes the central optimization problem different from a desktop GUI: the most important cost is not drawing a few extra Lua tables, but sending unnecessary writes to the GPU.

## Packet manager architecture

The repository is organized as a source tree that can also act as a package repository. `src/manifest.lua` describes named packages. Each package declares its files, dependencies, optional runnable entrypoint, and description. The installer resolves the dependency graph before downloading files, so an application can depend on shared compose or telemetry packages without duplicating their contents.

The installer uses a staging directory. It downloads the manifest and package files into staging, validates the paths, and only then commits the complete installation. A downloaded file that is byte-identical to the installed copy is dropped from the stage immediately, so an update only needs free space for the files that actually changed. Existing files are moved into temporary backups during the commit and restored if a later replacement fails. Files retired by the new package graph go through the same backup-and-rollback path instead of accumulating forever. This keeps a failed update from leaving a half-installed runtime or destroying the currently installed manifest.

The manifest is a first-class part of the packet manager. `--list` attempts to refresh it from the configured source and falls back to the local copy when the source is unavailable. `--dry-run` resolves the same package graph and prints the planned packages and files without writing them. The source URL is stored locally so a computer can switch between the public repository and a local development server.

`run.lua` is the execution boundary after installation. It resolves the installed packages, adds the local package tree to Lua's module path, validates the requested target, and reloads project modules before execution. Reloading is important in OpenComputers because Lua caches `require` results across runs; development code can be updated and executed without rebooting the computer.

This makes the project more than a collection of scripts. The manifest is the package contract, the installer is the deployment mechanism, and the runner is the runtime entrypoint for installed Lua programs. The UI engine and applications are consumers of that package infrastructure.

## The rendering pipeline

Every application follows the same one-way pipeline:

```text
state / input / effects
          |
          v
  declarative composition tree
          |
          v
       measurement
          |
          v
   character framebuffer
          |
          v
    diff against previous frame
          |
          v
      minimal GPU writes
```

The application describes what the screen should look like. The engine measures that description against the current screen resolution, draws it into an off-screen character framebuffer, and compares the result with the previous frame before touching the GPU.

This gives the application a simple mental model while keeping hardware-facing work centralized in `lib/compose/renderer.lua` and `lib/compose/framebuffer.lua`.

## Why Compose-style UI fits OpenComputers

### State describes the result

A component does not need to remember which cells it previously painted. It reads state and returns nodes:

```lua
return compose.Text(
  "Status: " .. (online.value and "ONLINE" or "OFFLINE")
)
```

When `online` changes, the runtime invalidates the scopes that read it. The component describes the new result and the renderer handles the transition. There is no separate collection of imperative commands that must be manually undone when a dialog closes, a route changes, or a list item disappears.

That is particularly valuable in a TUI. A terminal screen is spatial and stateful, so imperative drawing tends to accumulate cleanup rules: clear this line, restore that color, repaint the old border, and remember which region is currently visible. Declarative composition makes the framebuffer the authority for the complete current image.

### Slots are positional

`remember`, `LaunchedEffect`, and `DisposableEffect` share one positional slot list per scope, exactly like Compose without `key {}`. A call that is skipped or added conditionally shifts every later slot. The runtime checks the kind of each slot on every composition and fails loudly when a state slot turns into an effect slot or vice versa; the fix is to make the call unconditional or to wrap the conditional subtree in a keyed `RecomposeScope`.

### Recomposition is scoped

The runtime does not blindly rebuild every remembered subtree. A `RecomposeScope` tracks the state values read by its content. When a value changes, the affected scope becomes dirty and its parents only traverse far enough to reach dirty descendants.

Scopes also own effects and disposable resources. When a route or accordion content disappears, its scope is disposed and its effects are cancelled. This keeps lifecycle behavior next to the UI that owns it instead of spreading cleanup code across event handlers.

The result is a useful balance:

- application code stays declarative;
- unrelated static component subtrees can be reused;
- changing state has a bounded invalidation path;
- effects follow the visibility and lifetime of their UI.

## Why the framebuffer matters

The engine does not issue a GPU call for every `Text` node or every character. It first produces a complete logical frame containing:

- character cells;
- foreground colors;
- background colors;
- blended colors from transparent layers;
- wide-character continuation cells.

`framebuffer.present` compares the current frame with the previous one. It then groups compatible changed cells into horizontal runs and reuses the currently selected foreground and background colors. The GPU receives `set` calls for changed runs, not a stream of redundant per-cell updates.

This is the most important performance property of the architecture. A state update may cause the engine to calculate a new frame, but an unchanged screen does not cause a full-screen GPU repaint.

The same design also makes overlays practical. A dialog scrim or semi-transparent surface is composited into the framebuffer first. The final resolved color is then diffed like every other cell, so alpha support does not require a special GPU protocol or a second rendering path.

## Layout and clipping

Layout is constraint-based rather than pixel-canvas-based. Nodes receive a bounded width and height, measure their children, and return their desired dimensions. Modifiers add constraints such as width, height, weight, padding, alignment, borders, and scrolling.

`Modifier:width()` and `Modifier:height()` are required sizes: they replace the incoming constraints rather than being coerced into them, so a fixed-size child can extend past its parent. Nothing clips except scroll viewports and the screen edge; use `weight` or `fillMaxWidth` when a node must stay inside its parent.

Modifier chains are persistent. Each call records one element and a parent pointer, and the flat element list that layout and rendering read is materialized once on first access. Building a long chain inside a hot composable therefore does not copy the list on every step.

Scrollable columns keep a viewport size while measuring their content. The renderer clips children to that viewport, so content outside the visible area does not overwrite surrounding bars or panels. Input hit-testing uses the same measured tree, which means clicks and scroll events are routed to the component that visually owns the region.

This shared layout model is important: drawing and input cannot quietly disagree about where a component is.

## Unicode and character-cell correctness

OpenComputers renders text in character cells, but Lua strings are byte sequences and not every Unicode character occupies one terminal column. Treating string length as screen width would make layout, clipping, borders, and GPU diffs incorrect as soon as a screen contains Cyrillic, CJK text, emoji, or combining characters.

The engine therefore uses the OC `unicode` library at the framebuffer and renderer boundaries:

- `unicode.len` counts characters rather than bytes;
- `unicode.sub` extracts complete characters;
- `unicode.wlen` measures display width in terminal columns;
- `unicode.charWidth` determines how many framebuffer cells a glyph occupies.

Layout uses display width, not byte length, when measuring text. Drawing walks the text by Unicode character, advances by the glyph width, and refuses to draw a glyph when its complete cell range is outside the visible clip. A wide glyph is never cut in half at the edge of a panel or screen.

The framebuffer stores a continuation marker in the second cell of a wide glyph. This preserves the relationship between the leading cell and its occupied continuation cell. When a diff detects a changed continuation cell, it also marks the corresponding leading cell for repaint; the same happens in reverse when a leading wide glyph changes. GPU writes therefore start at valid glyph boundaries.

This handling is deliberately kept below the component layer. Components can compose normal Lua strings, while layout, clipping, background fills, borders, and frame presentation consistently operate in terminal columns. Unicode support is consequently part of the renderer's correctness contract rather than a special case that each application must remember to implement.

## Color and alpha compositing

OpenComputers GPUs accept resolved RGB colors rather than a retained scene with an alpha channel. The engine therefore treats color mixing as a framebuffer operation. A plain RGB number represents an opaque color, while `compose.Color(rgb, alpha)` represents a layer whose alpha is between `0` and `1`; omitting alpha defaults to `1`.

For each cell, the framebuffer blends the source color over the color already present in that cell using ordinary source-over compositing for each RGB channel:

```text
result = source * alpha + destination * (1 - alpha)
```

Foreground and background colors are stored independently, but transparent text is resolved against the cell background so translucent glyphs can reveal the solid surface behind them. The final framebuffer contains only resolved RGB values. Alpha is not sent to the GPU because there is no second GPU-side blending stage to rely on.

Opaque and fully transparent colors have explicit fast paths. An opaque color replaces the destination without per-channel arithmetic, and a transparent color leaves the destination unchanged. This keeps the common case—the large number of ordinary opaque TUI cells—cheap while still allowing semi-transparent surfaces where they provide real value.

Scrims use the same mechanism. A dialog applies a transparent tint to both foreground and background across its clipped bounds, so the content underneath remains visually present but subdued. Multiple translucent layers are resolved in framebuffer order, which makes overlapping surfaces behave predictably without requiring special dialog or overlay rendering code. Text that spans mixed surfaces can opt into automatic contrast; the renderer evaluates the background under each cell and keeps the requested foreground when it is readable, otherwise selecting its negative or a black/white fallback.

Color resolution happens before frame diffing. If a translucent layer does not change the resolved RGB result, it produces no GPU write; if it does change the result, the normal changed-cell and horizontal-run batching applies. Alpha support therefore integrates with the same performance model as opaque drawing instead of creating a separate expensive presentation path.

## Components are composition boundaries

The component layer provides application-scale structure on top of primitive nodes:

- `Entrypoint` provides uptime, hardware status, navigation, bars, and a common application shell;
- `Scaffold` owns the screen structure, quit behavior, overlays, and modal input barriers;
- `TopAppBar` and `CommandBar` provide compact TUI chrome;
- `Grid` provides dense tables with shared borders and alignment;
- `Accordion` conditionally composes content;
- `BufferView` renders bounded streams such as live status or event output.

These are not separate rendering systems. They return the same compose nodes and use the same modifier, layout, input, and framebuffer pipeline as application code. That keeps components small and makes them composable instead of turning the application into a collection of special-case screens.

## Bounded memory and live streams

OpenComputers memory is finite and the Lua VM may retain allocations until garbage collection. Unbounded event histories are therefore unsafe by default.

The general-purpose `collections.RingBuffer` stores a fixed number of records and overwrites the oldest record when full. It lives outside Compose because timelines, analytics, and UI streams all use it. It never shifts the remaining entries or creates a complete snapshot on every append. `BufferView` subscribes only while it is composed, so a hidden stream does not keep a visible list recomposing.

The telemetry dashboard likewise caps its live source registry and evicts the least recently seen source when full. Telemetry and incident identities include the sender address and use length-prefixed fields rather than delimiter concatenation, so configured IDs cannot accidentally overwrite one another. The modem transport resolves its primary component for each send, reports non-throwing hardware failures, and distinguishes a port it opened from one that was already open.

Persistent history uses a shared OpenComputers-aware clock. OpenComputers reports `os.time()` in accelerated in-game seconds, so the clock converts it back to elapsed server seconds before values enter real-time chart windows. The world clock is read once at startup and time then advances with `computer.uptime()`, so `/time set`, sleeping through the night, or a frozen daylight cycle cannot jump or stall history during a session. This keeps timestamps persistent across computer restarts without making a 15-minute chart advance at Minecraft-day speed.

## Disk discipline

An OpenComputers hard drive holds one or two megabytes for the operating system, the installed packages, and every record an application writes. Persistence is designed around that:

- records are written through `lib/storage/store.lua`, which checks free space before writing and never prints over the running UI; a failure is kept on the store as `lastError` for the application to display;
- the temporary file used for atomic replacement is committed by removing the old record first, so the peak footprint is one record plus the new one only when the disk has room for both; an interrupted commit is recovered from the temporary file on the next load;
- persisted time series use positional bucket layouts with rounded values; the power monitor's full day of minute buckets plus its chart tiers is roughly 70 KB in practice and stays under 128 KB at its theoretical widest (`src/test/storage/footprint.lua` writes that worst case through the real store and asserts the budget); the dashboard's incident history stays under 24 KB;
- history is flushed in batches (every five minutes by default) because OC disk writes are slow and block the event loop.

When the user is already at the end of a stream, new records keep the view at the end. If the user scrolls upward, new records do not steal their position. That is the behavior expected from a useful compact TUI log or event panel.

## OC-aware resource discipline

The engine deliberately keeps hardware interaction behind narrow boundaries:

- the host owns event pulling and local-input filtering, caching the bound screen and keyboard addresses so routing an event does not cost several component calls;
- the renderer owns GPU access and frame presentation;
- hardware metrics are sampled periodically rather than on every composition;
- CPU and GPU activity are labeled estimates because OC does not expose native utilization counters;
- applications can use `RecomposeScope` and bounded buffers to control work and memory growth.

The goal is not to emulate a desktop GUI. It is to make a character-based screen feel like a coherent application while respecting the cost model of OC.

## Trade-offs

This architecture is intentionally pragmatic rather than magical:

- a layout invalidation still rebuilds and measures a framebuffer-sized image;
- very large trees should still be split into meaningful recomposition scopes;
- high-frequency timers should be used only for genuinely live UI;
- external component calls should not be placed in hot render paths;
- host checks validate Lua and repository behavior, but GPU, screen, keyboard, event, and OpenOS behavior still require execution inside GTNH OpenComputers.

For the target hardware, this is a good trade. Declarative code removes a large class of stale-screen and lifecycle bugs, while framebuffer diffing ensures that the expensive part—the actual GPU traffic—stays proportional to what changed.
