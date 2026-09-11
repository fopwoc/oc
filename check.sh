#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LUA_BIN="${LUA_BIN:-lua}"
LUAC_BIN="${LUAC_BIN:-luac}"

cd "$ROOT"

command -v "$LUA_BIN" >/dev/null 2>&1 \
  || { echo "missing Lua interpreter: $LUA_BIN" >&2; exit 1; }

command -v "$LUAC_BIN" >/dev/null 2>&1 \
  || { echo "missing Lua compiler: $LUAC_BIN" >&2; exit 1; }

while IFS= read -r -d '' file; do
  "$LUAC_BIN" -p "$file"
done < <(find src test -type f -name '*.lua' -print0 | sort -z)

bash -n check.sh
bash -n devserver.sh

"$LUA_BIN" scripts/check_manifest.lua
"$LUA_BIN" test/suite.lua

echo "check: OK"
