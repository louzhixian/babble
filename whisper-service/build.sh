#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check platform - requires Apple Silicon for MLX
if [ "$(uname -m)" != "arm64" ]; then
    echo "ERROR: This script requires Apple Silicon (ARM64) Mac"
    exit 1
fi

echo "=== Setting up build environment ==="
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate

echo "=== Installing dependencies ==="
pip install -r requirements.txt
pip install pyinstaller

# Verify PyInstaller is available
if ! command -v pyinstaller &> /dev/null; then
    echo "ERROR: PyInstaller installation failed"
    exit 1
fi

echo "=== Building with PyInstaller ==="
pyinstaller --clean --noconfirm whisper-service.spec

# Verify binary was created
if [ ! -f "dist/whisper-service" ]; then
    echo "ERROR: PyInstaller failed to create binary"
    exit 1
fi

echo "=== Generating checksum ==="
cd dist
shasum -a 256 whisper-service > whisper-service.sha256
cat whisper-service.sha256

echo ""
echo "=== Build complete ==="
echo "Binary: $SCRIPT_DIR/dist/whisper-service"
echo "Checksum: $SCRIPT_DIR/dist/whisper-service.sha256"
ls -lh whisper-service
