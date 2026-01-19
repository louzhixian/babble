#!/bin/bash
# Build Babble.app bundle with proper Info.plist and whisper-service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WHISPER_SERVICE_DIR="$PROJECT_DIR/whisper-service"

# Ensure whisper-service venv exists with dependencies
echo "Setting up whisper-service dependencies..."
if [ ! -d "$WHISPER_SERVICE_DIR/.venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$WHISPER_SERVICE_DIR/.venv"
fi

echo "Installing/updating dependencies..."
"$WHISPER_SERVICE_DIR/.venv/bin/pip" install -q -r "$WHISPER_SERVICE_DIR/requirements.txt"

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

# Copy whisper-service (including .venv with dependencies)
echo "Bundling whisper-service..."
cp -r "$WHISPER_SERVICE_DIR" "$RESOURCES_DIR/"

echo ""
echo "Built Babble.app at $APP_DIR"
echo "Note: whisper-service with dependencies bundled in Resources/"
