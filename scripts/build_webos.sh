#!/bin/bash
# =============================================================================
# Plezy webOS Build Script
#
# Builds the Flutter web app and packages it as a webOS IPK for LG TVs.
#
# Prerequisites:
#   - Flutter SDK installed and in PATH
#   - webOS CLI tools (ares-*) installed: npm install -g @webos-tools/cli
#   - For deployment: webOS TV in Developer Mode with ares-setup-device configured
#
# Usage:
#   ./scripts/build_webos.sh           # Build only
#   ./scripts/build_webos.sh --deploy  # Build and deploy to connected TV
#   ./scripts/build_webos.sh --debug   # Build in debug mode
#   ./scripts/build_webos.sh --html    # Use HTML renderer (for older TVs)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build/web"
WEBOS_DIR="$PROJECT_DIR/webos"
OUTPUT_DIR="$PROJECT_DIR/build/webos"
DEPLOY=false
DEBUG=false
RENDERER="canvaskit"

# Parse arguments
for arg in "$@"; do
  case $arg in
    --deploy) DEPLOY=true ;;
    --debug) DEBUG=true ;;
    --html) RENDERER="html" ;;
    --help)
      echo "Usage: $0 [--deploy] [--debug] [--html]"
      echo "  --deploy  Install IPK on connected webOS TV"
      echo "  --debug   Build in debug mode (profile)"
      echo "  --html    Use HTML renderer (better for older/low-end TVs)"
      exit 0
      ;;
  esac
done

echo "================================================"
echo "  Plezy webOS Build"
echo "================================================"
echo ""

# Validate prerequisites
if ! command -v flutter &> /dev/null; then
  echo "Error: Flutter SDK not found. Please install Flutter and add it to PATH."
  exit 1
fi

echo "Using renderer: $RENDERER"
echo ""

# Step 1: Build Flutter web
echo "[1/4] Building Flutter web app..."
cd "$PROJECT_DIR"

BUILD_ARGS="--web-renderer $RENDERER"
if [ "$RENDERER" = "canvaskit" ]; then
  BUILD_ARGS="$BUILD_ARGS --dart-define=FLUTTER_WEB_CANVASKIT_URL=canvaskit/"
fi

if [ "$DEBUG" = true ]; then
  flutter build web --profile $BUILD_ARGS
else
  flutter build web --release $BUILD_ARGS
fi

echo "  Flutter web build complete."
echo ""

# Step 2: Prepare webOS package directory
echo "[2/4] Preparing webOS package..."
mkdir -p "$OUTPUT_DIR"

# Copy Flutter web build output
if [ -d "$BUILD_DIR" ] && [ "$(ls -A "$BUILD_DIR" 2>/dev/null)" ]; then
  cp -r "$BUILD_DIR/." "$OUTPUT_DIR/"
else
  echo "Error: Flutter web build output not found at $BUILD_DIR"
  exit 1
fi

# Copy webOS app metadata
if [ -f "$WEBOS_DIR/appinfo.json" ]; then
  cp "$WEBOS_DIR/appinfo.json" "$OUTPUT_DIR/"
else
  echo "Error: webOS appinfo.json not found at $WEBOS_DIR/appinfo.json"
  exit 1
fi

# Copy icons (generate from assets if not present)
if [ -f "$WEBOS_DIR/icon.png" ]; then
  cp "$WEBOS_DIR/icon.png" "$OUTPUT_DIR/"
elif [ -f "$PROJECT_DIR/assets/plezy.png" ]; then
  echo "  Warning: No icon.png in webos/ directory. Using placeholder."
  cp "$PROJECT_DIR/assets/plezy.png" "$OUTPUT_DIR/icon.png"
else
  echo "  Warning: No icon found. Create webos/icon.png (80x80) for the app icon."
fi

if [ -f "$WEBOS_DIR/largeIcon.png" ]; then
  cp "$WEBOS_DIR/largeIcon.png" "$OUTPUT_DIR/"
elif [ -f "$PROJECT_DIR/assets/plezy.png" ]; then
  echo "  Warning: No largeIcon.png in webos/ directory. Using placeholder."
  cp "$PROJECT_DIR/assets/plezy.png" "$OUTPUT_DIR/largeIcon.png"
else
  echo "  Warning: No large icon found. Create webos/largeIcon.png (130x130) for the launcher."
fi

echo "  Package directory prepared."
echo ""

# Step 3: Package as IPK
echo "[3/4] Packaging IPK..."
IPK_FILE=""
if command -v ares-package &> /dev/null; then
  cd "$PROJECT_DIR/build"
  ares-package webos -o "$PROJECT_DIR/build/"
  IPK_FILE=$(ls -t "$PROJECT_DIR/build/"*.ipk 2>/dev/null | head -1)
  if [ -n "$IPK_FILE" ]; then
    echo "  IPK created: $IPK_FILE"
  else
    echo "  Warning: IPK file not found after packaging. Check ares-package output."
  fi
else
  echo "  Warning: ares-package not found. Install webOS CLI tools:"
  echo "    npm install -g @webos-tools/cli"
  echo "  Skipping IPK packaging. Web build is available at: $OUTPUT_DIR/"
fi
echo ""

# Step 4: Deploy (optional)
if [ "$DEPLOY" = true ]; then
  echo "[4/4] Deploying to webOS TV..."
  if [ -z "$IPK_FILE" ]; then
    echo "  Error: No IPK file to deploy. Build the IPK first."
    exit 1
  fi
  if ! command -v ares-install &> /dev/null; then
    echo "  Error: ares-install not found. Install webOS CLI tools:"
    echo "    npm install -g @webos-tools/cli"
    exit 1
  fi
  ares-install "$IPK_FILE"
  echo "  Deployed successfully!"

  # Optionally launch the app
  echo "  Launching app..."
  ares-launch com.plezy.app
else
  echo "[4/4] Skipping deployment (use --deploy to install on TV)."
fi

echo ""
echo "================================================"
echo "  Build complete!"
if [ -n "$IPK_FILE" ]; then
  echo "  IPK: $IPK_FILE"
fi
echo "  Web: $OUTPUT_DIR/"
echo "================================================"
