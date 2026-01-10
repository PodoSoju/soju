#!/bin/bash
# Patch winemac.drv in Gcenx Wine binary
#
# Downloads Gcenx wine-staging binary, patches only winemac.drv from Wine source,
# and replaces the binary's winemac.drv.so with the patched version.
#
# Usage:
#   ./scripts/patch-winemac.sh
#
# Requirements:
#   - Xcode Command Line Tools (for clang)
#   - x86_64 architecture support (Rosetta 2 on Apple Silicon)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORK_DIR="$PROJECT_ROOT/.patch-work"
PATCHES_DIR="$PROJECT_ROOT/patches"
OUTPUT_DIR="$PROJECT_ROOT/dist"

# Version config
WINE_VERSION="${WINE_VERSION:-11.0-rc5}"

# Download URLs
GCENX_BINARY_URL="https://github.com/Gcenx/macOS_Wine_builds/releases/download/${WINE_VERSION}/wine-staging-${WINE_VERSION}-osx64.tar.xz"
WINE_SOURCE_URL="https://github.com/wine-mirror/wine/archive/refs/tags/wine-${WINE_VERSION}.tar.gz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[$1]${NC} $2"; }

cleanup_on_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Script failed with exit code $exit_code"
        log_error "Work directory preserved at: $WORK_DIR"
        log_error "Check the logs above for details"
    fi
}

trap cleanup_on_error EXIT

echo "============================================"
echo "Gcenx Wine + winemac.drv Patch"
echo "============================================"
echo "Wine Version: ${WINE_VERSION}"
echo "Work Dir:     ${WORK_DIR}"
echo "============================================"
echo ""

# Check dependencies
check_dependencies() {
    log_step "0/6" "Checking dependencies..."
    local missing=()

    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v tar >/dev/null 2>&1 || missing+=("tar")
    command -v xz >/dev/null 2>&1 || missing+=("xz")
    command -v patch >/dev/null 2>&1 || missing+=("patch")
    command -v clang >/dev/null 2>&1 || missing+=("clang (Xcode Command Line Tools)")
    command -v make >/dev/null 2>&1 || missing+=("make")

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_error "Install Xcode Command Line Tools: xcode-select --install"
        exit 1
    fi

    # Check for x86_64 support
    if [[ "$(uname -m)" == "arm64" ]]; then
        if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
            log_error "Rosetta 2 not installed. Install with: softwareupdate --install-rosetta"
            exit 1
        fi
        log_info "  Running on Apple Silicon with Rosetta 2"
    fi

    log_info "  All dependencies satisfied"
}

# [1/6] Download Gcenx Wine binary
download_gcenx_binary() {
    log_step "1/6" "Downloading Gcenx Wine binary..."

    local archive="$WORK_DIR/gcenx-wine.tar.xz"
    local extract_dir="$WORK_DIR/gcenx-wine"
    local wine_bin="$extract_dir/Contents/Resources/wine/bin/wine"

    mkdir -p "$WORK_DIR"

    # Skip if already extracted and valid
    if [ -f "$wine_bin" ]; then
        log_info "  Gcenx Wine binary already exists, skipping download"
        return 0
    fi

    # Download if archive doesn't exist
    if [ ! -f "$archive" ]; then
        log_info "  Downloading from GitHub..."
        local max_retries=3
        local retry=0

        while [ $retry -lt $max_retries ]; do
            if curl -fsSL -o "$archive.tmp" "$GCENX_BINARY_URL"; then
                mv "$archive.tmp" "$archive"
                log_info "  Download complete ($(du -h "$archive" | cut -f1))"
                break
            else
                retry=$((retry + 1))
                log_warn "  Download failed, retry $retry/$max_retries"
                rm -f "$archive.tmp"
                sleep 2
            fi
        done

        if [ $retry -eq $max_retries ]; then
            log_error "Failed to download Gcenx Wine binary after $max_retries attempts"
            exit 1
        fi
    else
        log_info "  Archive already exists, skipping download"
    fi

    # Extract
    if [ ! -d "$extract_dir" ]; then
        log_info "  Extracting archive..."
        mkdir -p "$extract_dir"
        tar -xJf "$archive" -C "$extract_dir" --strip-components=1
        log_info "  Extraction complete"
    fi

    # Verify extraction
    if [ ! -f "$wine_bin" ]; then
        log_error "Wine binary not found after extraction"
        log_error "Expected: $wine_bin"
        exit 1
    fi
}

# [2/6] Download Wine source (for winemac.drv build)
download_wine_source() {
    log_step "2/6" "Downloading Wine source (for winemac.drv)..."

    local archive="$WORK_DIR/wine-source.tar.gz"
    local extract_dir="$WORK_DIR/wine-source"
    local configure="$extract_dir/configure"

    # Skip if already extracted
    if [ -f "$configure" ]; then
        log_info "  Wine source already exists, skipping download"
        return 0
    fi

    # Download if archive doesn't exist
    if [ ! -f "$archive" ]; then
        log_info "  Downloading from GitHub..."
        local max_retries=3
        local retry=0

        while [ $retry -lt $max_retries ]; do
            if curl -fsSL -o "$archive.tmp" "$WINE_SOURCE_URL"; then
                mv "$archive.tmp" "$archive"
                log_info "  Download complete ($(du -h "$archive" | cut -f1))"
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

    # Extract
    if [ ! -d "$extract_dir" ]; then
        log_info "  Extracting archive..."
        mkdir -p "$extract_dir"
        tar -xzf "$archive" -C "$extract_dir" --strip-components=1
        log_info "  Extraction complete"
    fi

    # Verify extraction
    if [ ! -f "$configure" ]; then
        log_error "Wine configure script not found after extraction"
        exit 1
    fi
}

# [3/6] Apply patches to Wine source
apply_patches() {
    log_step "3/6" "Applying patches..."

    local wine_src="$WORK_DIR/wine-source"
    local patch_file="$PATCHES_DIR/0001-winemac-add-window-identifier.patch"

    if [ ! -f "$patch_file" ]; then
        log_error "Patch file not found: $patch_file"
        exit 1
    fi

    cd "$wine_src"

    local patch_name=$(basename "$patch_file")
    local patch_marker="$wine_src/.patch_applied_${patch_name}"

    # Skip if already applied
    if [ -f "$patch_marker" ]; then
        log_info "  Patch already applied: $patch_name"
        cd "$PROJECT_ROOT"
        return 0
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
            log_error "Patch cannot be applied cleanly: $patch_name"
            log_error "The source may have changed or conflicts exist"
            exit 1
        fi
    fi

    cd "$PROJECT_ROOT"
}

# [4/6] Build winemac.drv only
build_winemac_drv() {
    log_step "4/6" "Building winemac.drv..."

    local wine_src="$WORK_DIR/wine-source"
    local build_dir="$WORK_DIR/wine-build"
    local build_marker="$build_dir/.winemac_build_complete"
    local target_so="$build_dir/dlls/winemac.drv/winemac.drv.so"

    # Skip if already built
    if [ -f "$build_marker" ] && [ -f "$target_so" ]; then
        log_info "  winemac.drv already built, skipping"
        return 0
    fi

    mkdir -p "$build_dir"
    cd "$build_dir"

    # Configure (minimal, only what's needed for winemac.drv)
    if [ ! -f "$build_dir/Makefile" ]; then
        log_info "  Configuring Wine (x86_64 only, minimal)..."

        # Use arch -x86_64 on Apple Silicon
        local configure_cmd="$wine_src/configure"
        local arch_prefix=""

        if [[ "$(uname -m)" == "arm64" ]]; then
            arch_prefix="arch -x86_64"
        fi

        # Configure with minimal options for winemac.drv build
        # We need Objective-C support for macOS driver
        $arch_prefix "$configure_cmd" \
            --enable-archs=x86_64 \
            --without-x \
            --without-freetype \
            --without-gnutls \
            --without-krb5 \
            --without-cups \
            --without-vulkan \
            --without-opengl \
            --without-pcap \
            --without-usb \
            --without-v4l2 \
            --without-gphoto \
            --without-sane \
            --without-pulse \
            --without-oss \
            --without-alsa \
            --without-capi \
            --without-netapi \
            --without-sdl \
            --without-gstreamer \
            --without-opencl \
            --without-inotify \
            --without-udev 2>&1 | tee "$build_dir/configure.log"

        if [ ! -f "$build_dir/Makefile" ]; then
            log_error "Configure failed. Check $build_dir/configure.log"
            exit 1
        fi
        log_info "  Configure complete"
    else
        log_info "  Makefile exists, skipping configure"
    fi

    # Build only winemac.drv and its dependencies
    log_info "  Building winemac.drv..."

    # Determine number of parallel jobs
    local jobs
    if [[ "$(uname -m)" == "arm64" ]]; then
        # Use arch -x86_64 for build on Apple Silicon
        jobs=$(sysctl -n hw.ncpu)
        arch -x86_64 make -j"$jobs" dlls/winemac.drv/winemac.drv.so 2>&1 | tee "$build_dir/build.log"
    else
        jobs=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
        make -j"$jobs" dlls/winemac.drv/winemac.drv.so 2>&1 | tee "$build_dir/build.log"
    fi

    # Verify build
    if [ ! -f "$target_so" ]; then
        log_error "winemac.drv.so not found after build"
        log_error "Check $build_dir/build.log for details"
        exit 1
    fi

    touch "$build_marker"
    log_info "  Build complete: $(du -h "$target_so" | cut -f1)"

    cd "$PROJECT_ROOT"
}

# [5/6] Replace winemac.drv in Gcenx binary
replace_winemac_drv() {
    log_step "5/6" "Replacing winemac.drv in Gcenx binary..."

    local gcenx_wine="$WORK_DIR/gcenx-wine/Contents/Resources/wine"
    local built_so="$WORK_DIR/wine-build/dlls/winemac.drv/winemac.drv.so"
    local target_so="$gcenx_wine/lib/wine/x86_64-unix/winemac.drv.so"

    # Verify source and target
    if [ ! -f "$built_so" ]; then
        log_error "Built winemac.drv.so not found: $built_so"
        exit 1
    fi

    if [ ! -f "$target_so" ]; then
        log_error "Target winemac.drv.so not found in Gcenx binary"
        log_error "Expected: $target_so"
        # List actual location
        log_info "Searching for winemac.drv.so in Gcenx binary..."
        find "$gcenx_wine" -name "winemac.drv.so" -type f 2>/dev/null || true
        exit 1
    fi

    # Backup original
    local backup_so="${target_so}.original"
    if [ ! -f "$backup_so" ]; then
        log_info "  Backing up original: $(basename "$target_so")"
        cp "$target_so" "$backup_so"
    else
        log_info "  Backup already exists"
    fi

    # Replace with patched version
    log_info "  Replacing with patched version..."
    cp "$built_so" "$target_so"

    # Verify replacement
    if [ -f "$target_so" ]; then
        log_info "  Replacement complete"
        log_info "  Original: $(du -h "$backup_so" | cut -f1)"
        log_info "  Patched:  $(du -h "$target_so" | cut -f1)"
    else
        log_error "Replacement failed"
        exit 1
    fi
}

# [6/6] Verify and test
verify_and_test() {
    log_step "6/6" "Verifying installation..."

    local gcenx_wine="$WORK_DIR/gcenx-wine/Contents/Resources/wine"
    local wine_bin="$gcenx_wine/bin/wine"

    # Test wine --version
    log_info "  Testing wine --version..."

    local wine_version
    if [[ "$(uname -m)" == "arm64" ]]; then
        wine_version=$(arch -x86_64 "$wine_bin" --version 2>/dev/null || echo "FAILED")
    else
        wine_version=$("$wine_bin" --version 2>/dev/null || echo "FAILED")
    fi

    if [ "$wine_version" == "FAILED" ]; then
        log_error "wine --version failed"
        exit 1
    fi

    log_info "  Wine version: $wine_version"

    # Check patched .so is loaded correctly (basic check)
    local target_so="$gcenx_wine/lib/wine/x86_64-unix/winemac.drv.so"
    if file "$target_so" | grep -q "Mach-O"; then
        log_info "  winemac.drv.so is valid Mach-O binary"
    else
        log_warn "  winemac.drv.so format check inconclusive"
    fi

    echo ""
    echo "============================================"
    echo "Patch Complete!"
    echo "============================================"
    echo ""
    echo "Patched Wine location:"
    echo "  $gcenx_wine"
    echo ""
    echo "To use this Wine:"
    echo "  export WINE_PREFIX=\"$gcenx_wine\""
    echo "  \$WINE_PREFIX/bin/wine64 your_app.exe"
    echo ""
    echo "To restore original winemac.drv:"
    echo "  cp \"$target_so.original\" \"$target_so\""
    echo ""
    echo "============================================"
}

# Main execution
main() {
    check_dependencies
    download_gcenx_binary
    download_wine_source
    apply_patches
    build_winemac_drv
    replace_winemac_drv
    verify_and_test
}

main "$@"
