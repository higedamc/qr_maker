#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

if ! command -v xcodegen &> /dev/null; then
    echo "Error: xcodegen is not installed."
    echo "Install via: brew install xcodegen"
    exit 1
fi

echo "==> Generating Xcode project..."
xcodegen generate --quiet

echo "==> Building QRMaker (Release)..."
xcodebuild \
    -project QRMaker.xcodeproj \
    -scheme QRMaker \
    -configuration Release \
    -derivedDataPath build \
    build \
    2>&1 | tail -5

APP_PATH="build/Build/Products/Release/QRMaker.app"
if [ -d "$APP_PATH" ]; then
    echo ""
    echo "==> Build succeeded: $APP_PATH"
    echo "    Run with: open $APP_PATH"
else
    echo ""
    echo "==> Build output not found at expected path."
    echo "    Check xcodebuild output above."
    exit 1
fi
