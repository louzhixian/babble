#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Setting up build environment ==="
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate

echo "=== Installing dependencies ==="
pip install -q -r requirements.txt
pip install -q pyinstaller

echo "=== Building with PyInstaller ==="
pyinstaller --clean --noconfirm whisper-service.spec

echo "=== Generating checksum ==="
cd dist
shasum -a 256 whisper-service > whisper-service.sha256
cat whisper-service.sha256

echo ""
echo "=== Build complete ==="
echo "Binary: $SCRIPT_DIR/dist/whisper-service"
echo "Checksum: $SCRIPT_DIR/dist/whisper-service.sha256"
ls -lh whisper-service
