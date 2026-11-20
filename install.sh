#!/bin/bash
# One command to get Stella's Snow running. In Terminal, in this folder:
#
#     bash install.sh
#
# - If StellaSnow.app is already in this folder (built on another Mac and
#   AirDropped over), it installs that.
# - Otherwise, if this Mac can compile Swift, it builds the app first.
# Installs to your own Applications folder, so no admin password is needed.
set -euo pipefail
cd "$(dirname "$0")"

ver="$(sw_vers -productVersion)"
if [ "${ver%%.*}" -lt 14 ]; then
  echo "This Mac has macOS $ver. Stella's Snow needs macOS 14 (Sonoma) or newer."
  echo "Open StellaSnow.html in Safari instead."
  exit 1
fi

# Always build fresh when this Mac can compile, so updated files are used.
if xcode-select -p >/dev/null 2>&1; then
  bash build.sh
elif [ ! -d StellaSnow.app ]; then
    echo "There's no StellaSnow.app in this folder, and this Mac can't build one"
    echo "(no Xcode or Command Line Tools)."
    echo
    echo "  1. On a Mac that has Xcode, run:  bash build.sh"
    echo "  2. AirDrop the StellaSnow.app it makes into this folder."
    echo "  3. Run this again:  bash install.sh"
    echo
    echo "Or open StellaSnow.html in Safari right now."
    exit 1
fi

DEST="$HOME/Applications"
mkdir -p "$DEST"
pkill -x StellaSnow 2>/dev/null || true
rm -rf "$DEST/StellaSnow.app"
cp -R StellaSnow.app "$DEST/"
# AirDropped apps are marked "downloaded"; clear that so it opens normally.
xattr -dr com.apple.quarantine "$DEST/StellaSnow.app" 2>/dev/null || true
open "$DEST/StellaSnow.app"
echo
echo "Stella's Snow is running. Look for the snowflake in the menu bar (top right)."
echo "To start it later: open the Applications folder in your home folder."
