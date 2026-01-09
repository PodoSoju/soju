#!/bin/bash
# Soju CI build script
# Wine + DXMT + DXVK + CJK fonts packaging
#
# Usage:
#   ./scripts/build-ci.sh [version]
#
# Environment variables:
#   WINE_VERSION - Wine-Staging version (default: 11.0-rc4)
#   DXMT_VERSION - DXMT version (default: v0.72)
#   DXVK_VERSION - DXVK version (default: v2.7.1)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/dist"

# Version config
WINE_VERSION="${WINE_VERSION:-11.0-rc4}"
DXMT_VERSION="${DXMT_VERSION:-v0.72}"
DXVK_VERSION="${DXVK_VERSION:-v2.7.1}"

# Download URLs
WINE_URL="https://github.com/Gcenx/macOS_Wine_builds/releases/download/${WINE_VERSION}/wine-staging-${WINE_VERSION}-osx64.tar.xz"
DXMT_URL="https://github.com/3Shain/dxmt/releases/download/${DXMT_VERSION}/dxmt-${DXMT_VERSION}-builtin.tar.gz"
DXVK_URL="https://github.com/doitsujin/dxvk/releases/download/${DXVK_VERSION}/dxvk-${DXVK_VERSION#v}.tar.gz"

# Temp directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "============================================"
echo "Soju CI Build"
echo "============================================"
echo "Wine:  ${WINE_VERSION}"
echo "DXMT:  ${DXMT_VERSION}"
echo "DXVK:  ${DXVK_VERSION}"
echo "============================================"
echo ""

# Create output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/Libraries/Soju"

# [1/5] Wine-Staging download
echo "[1/5] Wine-Staging ${WINE_VERSION} downloading..."
curl -fsSL -o "$TEMP_DIR/wine.tar.xz" "$WINE_URL"
mkdir -p "$TEMP_DIR/wine"
tar -xJf "$TEMP_DIR/wine.tar.xz" -C "$TEMP_DIR/wine" --strip-components=1
WINE_SOURCE="$TEMP_DIR/wine/Contents/Resources/wine"

# Wine copy
cp -R "$WINE_SOURCE/bin" "$OUTPUT_DIR/Libraries/Soju/"
cp -R "$WINE_SOURCE/lib" "$OUTPUT_DIR/Libraries/Soju/"
cp -R "$WINE_SOURCE/share" "$OUTPUT_DIR/Libraries/Soju/"
chmod +x "$OUTPUT_DIR/Libraries/Soju/bin/"*
echo "  Wine copy complete"

# [2/5] DXMT download and integrate
echo "[2/5] DXMT ${DXMT_VERSION} downloading..."
curl -fsSL -o "$TEMP_DIR/dxmt.tar.gz" "$DXMT_URL"
mkdir -p "$TEMP_DIR/dxmt"
tar -xzf "$TEMP_DIR/dxmt.tar.gz" -C "$TEMP_DIR/dxmt"

# DXMT DLL copy (x64)
mkdir -p "$OUTPUT_DIR/Libraries/Soju/lib/wine/x86_64-windows"
if [ -d "$TEMP_DIR/dxmt/x64" ]; then
    cp "$TEMP_DIR/dxmt/x64/"*.dll "$OUTPUT_DIR/Libraries/Soju/lib/wine/x86_64-windows/" 2>/dev/null || true
fi
echo "  DXMT integrated"

# [3/5] DXVK download and integrate
echo "[3/5] DXVK ${DXVK_VERSION} downloading..."
curl -fsSL -o "$TEMP_DIR/dxvk.tar.gz" "$DXVK_URL"
mkdir -p "$TEMP_DIR/dxvk"
tar -xzf "$TEMP_DIR/dxvk.tar.gz" -C "$TEMP_DIR/dxvk" --strip-components=1

# DXVK DLL copy (x64)
if [ -d "$TEMP_DIR/dxvk/x64" ]; then
    cp "$TEMP_DIR/dxvk/x64/"*.dll "$OUTPUT_DIR/Libraries/Soju/lib/wine/x86_64-windows/" 2>/dev/null || true
fi
echo "  DXVK integrated"

# [4/5] Copy CJK fonts
echo "[4/5] Copy CJK fonts..."
FONTS_DIR="$PROJECT_ROOT/fonts"
if [ -d "$FONTS_DIR" ]; then
    mkdir -p "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts"
    cp "$FONTS_DIR"/*.TTC "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts/" 2>/dev/null || true
    cp "$FONTS_DIR"/*.ttc "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts/" 2>/dev/null || true
    cp "$FONTS_DIR"/OFL-*.txt "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts/" 2>/dev/null || true
    echo "  CJK fonts added"
else
    echo "  fonts folder not found (skipped)"
fi

# [5/5] Generate version info and tarball
echo "[5/5] Generate version info..."

# Parse Wine version
MAJOR=$(echo "$WINE_VERSION" | sed -E 's/([0-9]+)\..*/\1/')
MINOR=$(echo "$WINE_VERSION" | sed -E 's/[0-9]+\.([0-9]+).*/\1/')
PRERELEASE=$(echo "$WINE_VERSION" | sed -E 's/.*-(rc[0-9]+).*/\1/' | grep -E '^rc' || echo "")
BUILD="staging"
PATCH="0"

echo "  version: $MAJOR.$MINOR${PRERELEASE:+-$PRERELEASE} ($BUILD)"

# Generate SojuVersion.plist
cat > "$OUTPUT_DIR/Libraries/SojuVersion.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>version</key>
    <dict>
        <key>major</key>
        <integer>$MAJOR</integer>
        <key>minor</key>
        <integer>$MINOR</integer>
        <key>patch</key>
        <integer>$PATCH</integer>
        <key>preRelease</key>
        <string>$PRERELEASE</string>
        <key>build</key>
        <string>$BUILD</string>
    </dict>
    <key>components</key>
    <dict>
        <key>wine</key>
        <string>${WINE_VERSION}</string>
        <key>dxmt</key>
        <string>${DXMT_VERSION}</string>
        <key>dxvk</key>
        <string>${DXVK_VERSION}</string>
    </dict>
</dict>
</plist>
PLIST

# Generate tarball
cd "$OUTPUT_DIR"
if [ -n "$PRERELEASE" ]; then
    TARBALL_NAME="Soju-${MAJOR}.${MINOR}-${PRERELEASE}.tar.gz"
else
    TARBALL_NAME="Soju-${MAJOR}.${MINOR}.${PATCH}.tar.gz"
fi
tar -czf "$TARBALL_NAME" Libraries

# Libraries cleanup (keep only tarball)
rm -rf Libraries

echo ""
echo "============================================"
echo "Build complete!"
echo "============================================"
echo "Output: $OUTPUT_DIR/$TARBALL_NAME"
echo ""
echo "Included components:"
echo "  - Wine-Staging ${WINE_VERSION}"
echo "  - DXMT ${DXMT_VERSION} (MIT license)"
echo "  - DXVK ${DXVK_VERSION} (zlib license)"
echo "  - CJK fonts"
echo "============================================"

# GitHub Actions output
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "tarball_name=$TARBALL_NAME" >> "$GITHUB_OUTPUT"
    echo "tarball_path=$OUTPUT_DIR/$TARBALL_NAME" >> "$GITHUB_OUTPUT"
    echo "version=${MAJOR}.${MINOR}${PRERELEASE:+-$PRERELEASE}" >> "$GITHUB_OUTPUT"
fi
