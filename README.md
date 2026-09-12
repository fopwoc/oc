# OC

This is my persona repo of OC lua projects for GTNH

It contains
- Primitive packet manager for downloading only needed code.
- `Compose`-like ui framework
- Components for `Compose`
- Bunch of test
- Crafter - craft requester
- Dashboard - metrics dashboard for crafters

![](.github/assets/image.png)
![](.github/assets/image_1.png)

> [!NOTE]
> This project contains AI-generated code. See [AI_USAGE.md](AI_USAGE.md) for details.

## Install in OpenComputers

From an OpenOS computer:

```sh
wget -f https://raw.githubusercontent.com/fopwoc/oc/master/src/install.lua ./install.lua
./install.lua --help
```

List installed targets or run one directly:

```sh
./run.lua --help
./run.lua test_components

# Search the connected AE2 network
./run.lua query metaitem.01

# Install and forward arguments to the target
./install.lua --run query metaitem.01
```
## Disk footprint

OpenComputers drives are small (1–2 MB). A single application with its dependencies is roughly 200–300 KB of Lua; `install all` is about 400 KB and includes every test suite. Install only the targets a computer runs. The power monitor keeps about 70 KB of history under `.data/`.

## Development

Host checks run with any Lua 5.3+ (`./check.sh`); OpenComputers itself runs Lua 5.3, so avoid 5.4-only features such as integer-for-loop overflow semantics, `<const>`, or `math.tointeger` edge cases.

## Structure

- `src/install.lua` — transactional packet installer and remote manifest loader
- `src/run.lua` — installed target runner with module reload support
- `src/manifest.lua` — package graph, dependencies, files, and entrypoints
- `src/lib/compose` — runtime, layout, renderer, input, colors, and navigation
- `src/lib/collections` — bounded data structures shared by UI and analytics
- `src/lib/utils` — time, number, formatting, and series helpers
- `src/lib/components` — application-level TUI components
- `src/app` — dashboard and crafter applications
- `src/test` — suites intended to run inside OpenComputers
- `test` — host-side repository checks

The design and performance rationale are described in [ARCHITECTURE.md](ARCHITECTURE.md).
