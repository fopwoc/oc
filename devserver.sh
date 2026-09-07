#!/usr/bin/env bash

# set local dev server
# cd && mkdir -p oc && cd oc && wget -f https://oc-dev.homelab.fopwoc.dev/install.lua ./install.lua && ./install.lua --url https://oc-dev.homelab.fopwoc.dev && ./install.lua --list

# cd && mkdir -p oc && cd oc && wget -f http://127.0.0.1:8000/install.lua ./install.lua && ./install.lua --url http://127.0.0.1:8000 && ./install.lua --list

set -euo pipefail

cd "$(dirname "$0")/src"
exec python3 -m http.server 8000 --bind 0.0.0.0
