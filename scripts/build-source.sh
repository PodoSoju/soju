#!/bin/bash
# Soju Source Build Script
# Wine source download, patch, build, and package
#
# Usage:
#   ./scripts/build-source.sh
#
# Environment variables:
#   WINE_VERSION - Wine version (default: 11.0-rc5)
#   DXMT_VERSION - DXMT version (default: v0.72)
#   DXVK_VERSION - DXVK version (default: v2.7.1)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="$PROJECT_ROOT/wine-source"
BUILD_DIR="$PROJECT_ROOT/wine-build"
OUTPUT_DIR="$PROJECT_ROOT/dist"
PATCHES_DIR="$PROJECT_ROOT/patches"

# Version config
WINE_VERSION="${WINE_VERSION:-11.0-rc5}"
DXMT_VERSION="${DXMT_VERSION:-v0.72}"
DXVK_VERSION="${DXVK_VERSION:-v2.7.1}"

# Download URLs
WINE_SOURCE_URL="https://github.com/wine-mirror/wine/archive/refs/tags/wine-${WINE_VERSION}.tar.gz"
DXMT_URL="https://github.com/3Shain/dxmt/releases/download/${DXMT_VERSION}/dxmt-${DXMT_VERSION}-builtin.tar.gz"
DXVK_URL="https://github.com/doitsujin/dxvk/releases/download/${DXVK_VERSION}/dxvk-${DXVK_VERSION#v}.tar.gz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "============================================"
echo "Soju Source Build"
echo "============================================"
echo "Wine:  ${WINE_VERSION}"
echo "DXMT:  ${DXMT_VERSION}"
echo "DXVK:  ${DXVK_VERSION}"
echo "============================================"
echo ""

# Check build dependencies
check_dependencies() {
    log_info "Checking build dependencies..."
    local missing=()

    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v tar >/dev/null 2>&1 || missing+=("tar")
    command -v make >/dev/null 2>&1 || missing+=("make")
    command -v patch >/dev/null 2>&1 || missing+=("patch")

    # macOS specific
    if [[ "$(uname)" == "Darwin" ]]; then
        command -v sysctl >/dev/null 2>&1 || missing+=("sysctl")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        exit 1
    fi
    log_info "All dependencies satisfied"
}

# [1/6] Download Wine source (idempotent)
download_wine_source() {
    log_info "[1/6] Wine source ${WINE_VERSION} downloading..."

    mkdir -p "$SOURCE_DIR"
    local archive="$SOURCE_DIR/wine-${WINE_VERSION}.tar.gz"
    local extract_dir="$SOURCE_DIR/wine-${WINE_VERSION}"

    # Skip if already extracted
    if [ -d "$extract_dir" ] && [ -f "$extract_dir/configure" ]; then
        log_info "  Wine source already exists, skipping download"
        return 0
    fi

    # Download if archive doesn't exist or is incomplete
    if [ ! -f "$archive" ] || [ ! -s "$archive" ]; then
        log_info "  Downloading from $WINE_SOURCE_URL"
        local max_retries=3
        local retry=0

        while [ $retry -lt $max_retries ]; do
            if curl -fsSL -o "$archive.tmp" "$WINE_SOURCE_URL"; then
                mv "$archive.tmp" "$archive"
                log_info "  Download complete"
                break
            else
                retry=$((retry + 1))
                log_warn "  Download failed, retry $retry/$max_retries"
                rm -f "$archive.tmp"
                sleep 2
            fi
        done

        if [ $retry -eq $max_retries ]; then
            log_error "Failed to download Wine source after $max_retries attempts"
            exit 1
        fi
    else
        log_info "  Archive already exists, skipping download"
    fi

    # Extract if not already extracted
    if [ ! -d "$extract_dir" ]; then
        log_info "  Extracting archive..."
        mkdir -p "$extract_dir"
        tar -xzf "$archive" -C "$extract_dir" --strip-components=1
        log_info "  Extraction complete"
    fi
}

# [2/6] Apply patches (idempotent)
apply_patches() {
    log_info "[2/6] Applying patches..."

    local wine_src="$SOURCE_DIR/wine-${WINE_VERSION}"

    if [ ! -d "$PATCHES_DIR" ]; then
        log_warn "  No patches directory found, skipping"
        return 0
    fi

    local patch_files=("$PATCHES_DIR"/*.patch)
    if [ ! -e "${patch_files[0]}" ]; then
        log_warn "  No patch files found, skipping"
        return 0
    fi

    cd "$wine_src"

    for patch_file in "${patch_files[@]}"; do
        local patch_name=$(basename "$patch_file")
        local patch_marker="$wine_src/.patch_applied_${patch_name}"

        # Skip if already applied
        if [ -f "$patch_marker" ]; then
            log_info "  Patch already applied: $patch_name"
            continue
        fi

        # Check if patch can be applied (dry-run)
        if patch -p1 --dry-run --silent < "$patch_file" 2>/dev/null; then
            log_info "  Applying: $patch_name"
            if patch -p1 < "$patch_file"; then
                touch "$patch_marker"
                log_info "  Successfully applied: $patch_name"
            else
                log_error "Failed to apply patch: $patch_name"
                exit 1
            fi
        else
            # Check if patch is already applied (reverse dry-run)
            if patch -p1 -R --dry-run --silent < "$patch_file" 2>/dev/null; then
                log_info "  Patch already applied (detected): $patch_name"
                touch "$patch_marker"
            else
                log_warn "  Patch cannot be applied cleanly: $patch_name"
                log_warn "  The patch may be partially applied or conflicts exist"
            fi
        fi
    done

    cd "$PROJECT_ROOT"
}

# [3/6] Build Wine
build_wine() {
    log_info "[3/6] Building Wine..."

    local wine_src="$SOURCE_DIR/wine-${WINE_VERSION}"
    local build_marker="$BUILD_DIR/.build_complete"

    # Skip if already built
    if [ -f "$build_marker" ] && [ -f "$BUILD_DIR/wine" ]; then
        log_info "  Wine already built, skipping"
        return 0
    fi

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # Configure
    if [ ! -f "$BUILD_DIR/Makefile" ]; then
        log_info "  Configuring Wine (x86_64 only)..."
        "$wine_src/configure" --enable-archs=x86_64
    else
        log_info "  Makefile exists, skipping configure"
    fi

    # Determine number of parallel jobs
    local jobs
    if [[ "$(uname)" == "Darwin" ]]; then
        jobs=$(sysctl -n hw.ncpu)
    else
        jobs=$(nproc 2>/dev/null || echo 4)
    fi

    log_info "  Building with $jobs parallel jobs..."
    make -j"$jobs"

    # Mark build as complete
    touch "$build_marker"
    log_info "  Build complete"

    cd "$PROJECT_ROOT"
}

# [4/6] Package Wine
package_wine() {
    log_info "[4/6] Packaging Wine..."

    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR/Libraries/Soju"

    local wine_build="$BUILD_DIR"

    # Copy built Wine
    if [ -d "$wine_build" ]; then
        # Install to temporary location
        log_info "  Installing Wine to package directory..."
        cd "$BUILD_DIR"
        make install DESTDIR="$OUTPUT_DIR/Libraries/Soju/_install" prefix=""

        # Move to final location
        if [ -d "$OUTPUT_DIR/Libraries/Soju/_install" ]; then
            mv "$OUTPUT_DIR/Libraries/Soju/_install/"* "$OUTPUT_DIR/Libraries/Soju/" 2>/dev/null || true
            rm -rf "$OUTPUT_DIR/Libraries/Soju/_install"
        fi

        cd "$PROJECT_ROOT"
    else
        log_error "Wine build directory not found"
        exit 1
    fi

    # Ensure bin executables are executable
    chmod +x "$OUTPUT_DIR/Libraries/Soju/bin/"* 2>/dev/null || true

    log_info "  Wine packaged"
}

# [5/6] Download and integrate DXMT/DXVK
integrate_graphics() {
    log_info "[5/6] Integrating graphics components..."

    local temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" RETURN

    mkdir -p "$OUTPUT_DIR/Libraries/Soju/lib/wine/x86_64-windows"

    # DXMT download and integrate
    log_info "  Downloading DXMT ${DXMT_VERSION}..."
    local dxmt_archive="$temp_dir/dxmt.tar.gz"
    local max_retries=3
    local retry=0

    while [ $retry -lt $max_retries ]; do
        if curl -fsSL -o "$dxmt_archive" "$DXMT_URL"; then
            break
        else
            retry=$((retry + 1))
            log_warn "  DXMT download failed, retry $retry/$max_retries"
            sleep 2
        fi
    done

    if [ -f "$dxmt_archive" ] && [ -s "$dxmt_archive" ]; then
        mkdir -p "$temp_dir/dxmt"
        tar -xzf "$dxmt_archive" -C "$temp_dir/dxmt"

        if [ -d "$temp_dir/dxmt/x64" ]; then
            cp "$temp_dir/dxmt/x64/"*.dll "$OUTPUT_DIR/Libraries/Soju/lib/wine/x86_64-windows/" 2>/dev/null || true
            log_info "  DXMT integrated"
        fi
    else
        log_warn "  Failed to download DXMT, skipping"
    fi

    # DXVK download and integrate
    log_info "  Downloading DXVK ${DXVK_VERSION}..."
    local dxvk_archive="$temp_dir/dxvk.tar.gz"
    retry=0

    while [ $retry -lt $max_retries ]; do
        if curl -fsSL -o "$dxvk_archive" "$DXVK_URL"; then
            break
        else
            retry=$((retry + 1))
            log_warn "  DXVK download failed, retry $retry/$max_retries"
            sleep 2
        fi
    done

    if [ -f "$dxvk_archive" ] && [ -s "$dxvk_archive" ]; then
        mkdir -p "$temp_dir/dxvk"
        tar -xzf "$dxvk_archive" -C "$temp_dir/dxvk" --strip-components=1

        if [ -d "$temp_dir/dxvk/x64" ]; then
            cp "$temp_dir/dxvk/x64/"*.dll "$OUTPUT_DIR/Libraries/Soju/lib/wine/x86_64-windows/" 2>/dev/null || true
            log_info "  DXVK integrated"
        fi
    else
        log_warn "  Failed to download DXVK, skipping"
    fi

    # Copy CJK fonts if available
    local fonts_dir="$PROJECT_ROOT/fonts"
    if [ -d "$fonts_dir" ]; then
        log_info "  Copying CJK fonts..."
        mkdir -p "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts"
        cp "$fonts_dir"/*.TTC "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts/" 2>/dev/null || true
        cp "$fonts_dir"/*.ttc "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts/" 2>/dev/null || true
        cp "$fonts_dir"/OFL-*.txt "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts/" 2>/dev/null || true
        log_info "  CJK fonts added"
    fi
}

# [6/6] Generate version info and tarball
generate_package() {
    log_info "[6/6] Generating version info and tarball..."

    # Parse Wine version
    local MAJOR=$(echo "$WINE_VERSION" | sed -E 's/([0-9]+)\..*/\1/')
    local MINOR=$(echo "$WINE_VERSION" | sed -E 's/[0-9]+\.([0-9]+).*/\1/')
    local PRERELEASE=$(echo "$WINE_VERSION" | sed -E 's/.*-(rc[0-9]+).*/\1/' | grep -E '^rc' || echo "")
    local BUILD="source"
    local PATCH="0"

    log_info "  Version: $MAJOR.$MINOR${PRERELEASE:+-$PRERELEASE} ($BUILD)"

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
    local TARBALL_NAME
    if [ -n "$PRERELEASE" ]; then
        TARBALL_NAME="Soju-${MAJOR}.${MINOR}-${PRERELEASE}.tar.gz"
    else
        TARBALL_NAME="Soju-${MAJOR}.${MINOR}.${PATCH}.tar.gz"
    fi

    tar -czf "$TARBALL_NAME" Libraries

    # Cleanup Libraries (keep only tarball)
    rm -rf Libraries

    echo ""
    echo "============================================"
    echo "Build complete!"
    echo "============================================"
    echo "Output: $OUTPUT_DIR/$TARBALL_NAME"
    echo ""
    echo "Included components:"
    echo "  - Wine ${WINE_VERSION} (source build)"
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
}

# Main execution
main() {
    check_dependencies
    download_wine_source
    apply_patches
    build_wine
    package_wine
    integrate_graphics
    generate_package
}

main "$@"
