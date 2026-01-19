#!/bin/bash
# Build Babble.app bundle with proper Info.plist

set -e

# Build release
swift build -c release

# Create app bundle structure
APP_DIR=".build/Babble.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

# Copy executable
cp .build/release/Babble "$MACOS_DIR/"

# Copy Info.plist
cp Info.plist "$CONTENTS_DIR/"

echo "Built Babble.app at $APP_DIR"
