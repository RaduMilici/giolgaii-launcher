#!/usr/bin/env bash
# Installs the unpacked Linux build into a WoW client folder and adds an app
# menu entry. Usage: scripts/install-linux.sh "/path/to/TurtleWoW client"
set -euo pipefail
cd "$(dirname "$0")/.."
client="${1:?usage: $0 <client folder>}"
dest="$client/GiolgaiiWoW"

npx electron-builder --linux dir
rm -rf "$dest"
cp -a dist/linux-unpacked "$dest"
mv "$dest/GiolgaiiWoW" "$dest/GiolgaiiWoW-bin"
gcc -O2 -o "$dest/GiolgaiiWoW" scripts/linux-wrapper.c
cp build/icon.png "$dest/icon.png"

apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$apps"
cat > "$apps/giolgaii-wow.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Giolgăii WoW
Comment=Launcher for the Giolgăii WoW realm
Exec="$dest/GiolgaiiWoW"
Path=$client
Icon=$dest/icon.png
Categories=Game;
StartupWMClass=Giolgăii WoW
DESKTOP
update-desktop-database "$apps" 2>/dev/null || true
echo "Installed to $dest"
