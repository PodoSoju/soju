#!/bin/bash
# Gcenx Wine-Staging for Soju packaging (idempotent)
#
# Usage:
#   ./scripts/package.sh
#
# Automatically download, extract, and package
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WINE_ROOT="$(dirname "$SCRIPT_DIR")"
WINE_STAGING_DIR="$HOME/Work/wine-staging"
GCENX_WINE="$WINE_STAGING_DIR/Contents/Resources/wine"
GPTK_WINE="/Applications/Game Porting Toolkit.app/Contents/Resources/wine"
OUTPUT_DIR="$WINE_ROOT/dist"

# Wine-Staging Version config
WINE_VERSION="11.0-rc4"
WINE_URL="https://github.com/Gcenx/macOS_Wine_builds/releases/download/${WINE_VERSION}/wine-staging-${WINE_VERSION}-osx64.tar.xz"

echo "============================================"
echo "Gcenx Wine-Staging → Soju Packaging"
echo "============================================"
echo ""

# Gcenx Wine download (if not exists)
if [ ! -f "$GCENX_WINE/bin/wine" ]; then
    echo "[0/4] Wine-Staging ${WINE_VERSION} downloading..."

    # download
    curl -L -o /tmp/wine-staging.tar.xz "$WINE_URL"

    # Extract
    rm -rf "$WINE_STAGING_DIR"
    mkdir -p "$WINE_STAGING_DIR"
    tar -xJf /tmp/wine-staging.tar.xz -C "$WINE_STAGING_DIR" --strip-components=1

    # Execution permission
    chmod +x "$GCENX_WINE/bin/"*
    chmod +x "$WINE_STAGING_DIR/Contents/MacOS/"* 2>/dev/null || true

    # Cleanup
    rm -f /tmp/wine-staging.tar.xz
    echo "  Download complete!"
    echo ""
fi

# Wine version check
WINE_VERSION=$(arch -x86_64 "$GCENX_WINE/bin/wine" --version 2>/dev/null | head -1)
echo "Wine version: $WINE_VERSION"

# Create output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/Libraries/Soju"

echo ""
echo "[1/4] Gcenx Wine copying..."
cp -R "$GCENX_WINE/bin" "$OUTPUT_DIR/Libraries/Soju/"
cp -R "$GCENX_WINE/lib" "$OUTPUT_DIR/Libraries/Soju/"
cp -R "$GCENX_WINE/share" "$OUTPUT_DIR/Libraries/Soju/"

# Execution permission check
chmod +x "$OUTPUT_DIR/Libraries/Soju/bin/"*

echo "[2/5] CJK fonts copying..."
FONTS_DIR="$WINE_ROOT/fonts"
if [ -d "$FONTS_DIR" ]; then
    mkdir -p "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts"
    cp "$FONTS_DIR"/*.TTC "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts/" 2>/dev/null || true
    cp "$FONTS_DIR"/*.ttc "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts/" 2>/dev/null || true
    cp "$FONTS_DIR"/OFL-*.txt "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts/" 2>/dev/null || true
    echo "  CJK fonts added"
else
    echo "  fonts folder not found"
fi

echo "[3/5] D3DMetal copy (GPTK)..."
if [ -d "$GPTK_WINE/lib/external/D3DMetal.framework" ]; then
    mkdir -p "$OUTPUT_DIR/Libraries/Soju/lib/external"
    cp -R "$GPTK_WINE/lib/external/D3DMetal.framework" "$OUTPUT_DIR/Libraries/Soju/lib/external/"
    cp "$GPTK_WINE/lib/external/libd3dshared.dylib" "$OUTPUT_DIR/Libraries/Soju/lib/external/" 2>/dev/null || true
    echo "  D3DMetal added"
else
    echo "  D3DMetal not found (GPTK not installed)"
fi

echo "[4/5] Generate version info..."
# Wine version parsing (e.g. wine-11.0-rc4 (Staging) → 11.0.0-rc4+staging)
WINE_VER_RAW=$(arch -x86_64 "$GCENX_WINE/bin/wine" --version 2>/dev/null)
# wine-11.0-rc4 (Staging) format parsing
MAJOR=$(echo "$WINE_VER_RAW" | sed -E 's/wine-([0-9]+)\..*/\1/')
MINOR=$(echo "$WINE_VER_RAW" | sed -E 's/wine-[0-9]+\.([0-9]+).*/\1/')
# rc version extract (empty string if not found)
PRERELEASE=$(echo "$WINE_VER_RAW" | sed -E 's/.*-(rc[0-9]+).*/\1/' | grep -E '^rc' || echo "")
# Staging check
BUILD=$(echo "$WINE_VER_RAW" | grep -i staging >/dev/null && echo "staging" || echo "")
# patch is always 0 (rc is in preRelease)
PATCH="0"

echo "  Soju version: $MAJOR.$MINOR-$PRERELEASE ($BUILD)"

# SojuVersion.plist generate (SemanticVersion format)
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
</dict>
</plist>
PLIST

echo "[5/5] tarball generating..."
cd "$OUTPUT_DIR"
# version name: 11.0-rc4 format
if [ -n "$PRERELEASE" ]; then
    TARBALL_NAME="Soju-${MAJOR}.${MINOR}-${PRERELEASE}.tar.gz"
else
    TARBALL_NAME="Soju-${MAJOR}.${MINOR}.${PATCH}.tar.gz"
fi
tar -czf "$TARBALL_NAME" Libraries
rm -rf Libraries

echo ""
echo "============================================"
echo "Done: $OUTPUT_DIR/$TARBALL_NAME"
echo "============================================"
