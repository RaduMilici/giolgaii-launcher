#!/usr/bin/env bash
# Checks the AzerothCompletion addon against the Lua that WoW 1.12 embeds (5.0.3):
#   1. every file must parse (catches '#', '%', goto and other 5.1+ syntax)
#   2. the addon runs against a mocked 1.12 API and fake server replies; every view is
#      rendered, every row/button clicked and hovered, and lists must not overflow.
# Usage: test/addon/check-addon.sh   (downloads and builds Lua 5.0.3 once, ~10 s)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
addon="$here/../../server/launcher-data/client/Interface/AddOns/AzerothCompletion"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/lua-5.0.3"
if [ ! -x "$cache/bin/lua" ]; then
  mkdir -p "$(dirname "$cache")"
  tmp="$(mktemp -d)"
  curl -sSfL https://www.lua.org/ftp/lua-5.0.3.tar.gz | tar xz -C "$tmp"
  make -s -C "$tmp/lua-5.0.3" >/dev/null
  rm -rf "$cache" && mv "$tmp/lua-5.0.3" "$cache"
fi
status=0
for f in "$addon"/*.lua; do "$cache/bin/luac" -p "$f" || status=1; done
[ $status -eq 0 ] || { echo "Syntax errors above (Lua 5.0)."; exit 1; }
cd "$here"
ADDON_DIR="$addon" "$cache/bin/lua" test_addon.lua | tee /dev/stderr | grep -q "^ERRORS: 0$"
