#!/bin/bash
# Build Babble.app bundle for lightweight distribution
#
# This script builds a small (~1MB) app bundle that does NOT include whisper-service.
# The whisper-service is downloaded automatically on first launch to:
#   ~/Library/Application Support/Babble/whisper-service/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build release
echo "Building Swift app..."
swift build -c release

# Create app bundle structure
APP_DIR=".build/Babble.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp .build/release/Babble "$MACOS_DIR/"

# Copy Info.plist
cp Info.plist "$CONTENTS_DIR/"

# Copy app icon
cp Resources/AppIcon.icns "$RESOURCES_DIR/"

# Ad-hoc sign with hardened runtime, explicit identifier, and entitlements
# The --identifier flag ensures the bundle identifier from Info.plist is used
# The --entitlements flag enables audio-input capability for microphone access with hardened runtime
codesign --force --deep --options runtime --identifier "com.babble.app" --entitlements Babble.entitlements --sign - "$APP_DIR"

echo ""
echo "Built Babble.app at $APP_DIR"
echo "Note: whisper-service will be downloaded on first launch"
