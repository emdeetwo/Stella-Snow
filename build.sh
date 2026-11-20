#!/bin/bash
# Build StellaSnow.app from the source in this folder.
# Needs Xcode or Apple's Command Line Tools. Usually run by install.sh.
# Builds for both Apple silicon and Intel, so an app built on any Mac runs
# on any other (AirDrop-friendly).
set -euo pipefail
cd "$(dirname "$0")"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "This Mac has no Swift compiler (no Xcode or Command Line Tools)."
  echo "Build on another Mac and AirDrop StellaSnow.app here, or open StellaSnow.html in Safari."
  exit 1
fi

SRC=(StellaSnowApp.swift SnowScene.swift SnowmanNode.swift YetiNode.swift PloughNode.swift
     OverlayWindow.swift Settings.swift ControlsView.swift WindowTracker.swift Textures.swift Art.swift)
FW=(-framework AppKit -framework SpriteKit -framework SwiftUI -framework ServiceManagement -framework AVFoundation)
APP="StellaSnow.app"
TMP="$(mktemp -d)"

echo "Building Stella's Snow (about a minute)..."
built=()
for arch in arm64 x86_64; do
  if swiftc -O -swift-version 5 -parse-as-library -target "$arch-apple-macos14.0" \
       -o "$TMP/StellaSnow-$arch" "${SRC[@]}" "${FW[@]}" 2>"$TMP/err-$arch.txt"; then
    built+=("$TMP/StellaSnow-$arch")
  elif [ "$arch" = "$(uname -m)" ]; then
    cat "$TMP/err-$arch.txt"
    echo
    echo "Build failed. Send the error text above back and it gets fixed."
    exit 1
  fi
done

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create -output "$APP/Contents/MacOS/StellaSnow" "${built[@]}"
sed 's/\$(EXECUTABLE_NAME)/StellaSnow/' Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp Wallpaper.jpg AppIcon.icns HouseLoop.mp4 "$APP/Contents/Resources/"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
rm -rf "$TMP"
echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/StellaSnow"))."
