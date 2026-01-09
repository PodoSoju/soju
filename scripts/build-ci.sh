#!/bin/bash
# PodoSoju CI 빌드 스크립트
# Wine + DXMT + DXVK + CJK 폰트 패키징
#
# 사용법:
#   ./scripts/build-ci.sh [version]
#
# 환경변수:
#   WINE_VERSION - Wine-Staging 버전 (기본값: 11.0-rc4)
#   DXMT_VERSION - DXMT 버전 (기본값: v0.72)
#   DXVK_VERSION - DXVK 버전 (기본값: v2.7.1)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/dist"

# 버전 설정
WINE_VERSION="${WINE_VERSION:-11.0-rc4}"
DXMT_VERSION="${DXMT_VERSION:-v0.72}"
DXVK_VERSION="${DXVK_VERSION:-v2.7.1}"

# 다운로드 URL
WINE_URL="https://github.com/Gcenx/macOS_Wine_builds/releases/download/${WINE_VERSION}/wine-staging-${WINE_VERSION}-osx64.tar.xz"
DXMT_URL="https://github.com/3Shain/dxmt/releases/download/${DXMT_VERSION}/dxmt-${DXMT_VERSION}-builtin.tar.gz"
DXVK_URL="https://github.com/doitsujin/dxvk/releases/download/${DXVK_VERSION}/dxvk-${DXVK_VERSION#v}.tar.gz"

# 임시 디렉토리
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "============================================"
echo "PodoSoju CI 빌드"
echo "============================================"
echo "Wine:  ${WINE_VERSION}"
echo "DXMT:  ${DXMT_VERSION}"
echo "DXVK:  ${DXVK_VERSION}"
echo "============================================"
echo ""

# 출력 디렉토리 생성
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/Libraries/PodoSoju"

# [1/5] Wine-Staging 다운로드
echo "[1/5] Wine-Staging ${WINE_VERSION} 다운로드..."
curl -fsSL -o "$TEMP_DIR/wine.tar.xz" "$WINE_URL"
mkdir -p "$TEMP_DIR/wine"
tar -xJf "$TEMP_DIR/wine.tar.xz" -C "$TEMP_DIR/wine" --strip-components=1
WINE_SOURCE="$TEMP_DIR/wine/Contents/Resources/wine"

# Wine 복사
cp -R "$WINE_SOURCE/bin" "$OUTPUT_DIR/Libraries/PodoSoju/"
cp -R "$WINE_SOURCE/lib" "$OUTPUT_DIR/Libraries/PodoSoju/"
cp -R "$WINE_SOURCE/share" "$OUTPUT_DIR/Libraries/PodoSoju/"
chmod +x "$OUTPUT_DIR/Libraries/PodoSoju/bin/"*
echo "  Wine 복사 완료"

# [2/5] DXMT 다운로드 및 통합
echo "[2/5] DXMT ${DXMT_VERSION} 다운로드..."
curl -fsSL -o "$TEMP_DIR/dxmt.tar.gz" "$DXMT_URL"
mkdir -p "$TEMP_DIR/dxmt"
tar -xzf "$TEMP_DIR/dxmt.tar.gz" -C "$TEMP_DIR/dxmt"

# DXMT DLL 복사 (x64용)
mkdir -p "$OUTPUT_DIR/Libraries/PodoSoju/lib/wine/x86_64-windows"
if [ -d "$TEMP_DIR/dxmt/x64" ]; then
    cp "$TEMP_DIR/dxmt/x64/"*.dll "$OUTPUT_DIR/Libraries/PodoSoju/lib/wine/x86_64-windows/" 2>/dev/null || true
fi
echo "  DXMT 통합 완료"

# [3/5] DXVK 다운로드 및 통합
echo "[3/5] DXVK ${DXVK_VERSION} 다운로드..."
curl -fsSL -o "$TEMP_DIR/dxvk.tar.gz" "$DXVK_URL"
mkdir -p "$TEMP_DIR/dxvk"
tar -xzf "$TEMP_DIR/dxvk.tar.gz" -C "$TEMP_DIR/dxvk" --strip-components=1

# DXVK DLL 복사 (x64용)
if [ -d "$TEMP_DIR/dxvk/x64" ]; then
    cp "$TEMP_DIR/dxvk/x64/"*.dll "$OUTPUT_DIR/Libraries/PodoSoju/lib/wine/x86_64-windows/" 2>/dev/null || true
fi
echo "  DXVK 통합 완료"

# [4/5] CJK 폰트 복사
echo "[4/5] CJK 폰트 복사..."
FONTS_DIR="$PROJECT_ROOT/fonts"
if [ -d "$FONTS_DIR" ]; then
    mkdir -p "$OUTPUT_DIR/Libraries/PodoSoju/share/wine/fonts"
    cp "$FONTS_DIR"/*.TTC "$OUTPUT_DIR/Libraries/PodoSoju/share/wine/fonts/" 2>/dev/null || true
    cp "$FONTS_DIR"/*.ttc "$OUTPUT_DIR/Libraries/PodoSoju/share/wine/fonts/" 2>/dev/null || true
    cp "$FONTS_DIR"/OFL-*.txt "$OUTPUT_DIR/Libraries/PodoSoju/share/wine/fonts/" 2>/dev/null || true
    echo "  CJK 폰트 추가됨"
else
    echo "  fonts 폴더 없음 (스킵)"
fi

# [5/5] 버전 정보 및 tarball 생성
echo "[5/5] 버전 정보 생성..."

# Wine 버전 파싱
MAJOR=$(echo "$WINE_VERSION" | sed -E 's/([0-9]+)\..*/\1/')
MINOR=$(echo "$WINE_VERSION" | sed -E 's/[0-9]+\.([0-9]+).*/\1/')
PRERELEASE=$(echo "$WINE_VERSION" | sed -E 's/.*-(rc[0-9]+).*/\1/' | grep -E '^rc' || echo "")
BUILD="staging"
PATCH="0"

echo "  버전: $MAJOR.$MINOR${PRERELEASE:+-$PRERELEASE} ($BUILD)"

# PodoSojuVersion.plist 생성
cat > "$OUTPUT_DIR/Libraries/PodoSojuVersion.plist" << PLIST
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

# tarball 생성
cd "$OUTPUT_DIR"
if [ -n "$PRERELEASE" ]; then
    TARBALL_NAME="PodoSoju-${MAJOR}.${MINOR}-${PRERELEASE}.tar.gz"
else
    TARBALL_NAME="PodoSoju-${MAJOR}.${MINOR}.${PATCH}.tar.gz"
fi
tar -czf "$TARBALL_NAME" Libraries

# Libraries 디렉토리 정리 (tarball만 남김)
rm -rf Libraries

echo ""
echo "============================================"
echo "빌드 완료!"
echo "============================================"
echo "출력: $OUTPUT_DIR/$TARBALL_NAME"
echo ""
echo "포함 구성요소:"
echo "  - Wine-Staging ${WINE_VERSION}"
echo "  - DXMT ${DXMT_VERSION} (MIT 라이선스)"
echo "  - DXVK ${DXVK_VERSION} (zlib 라이선스)"
echo "  - CJK 폰트"
echo "============================================"

# GitHub Actions 출력
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "tarball_name=$TARBALL_NAME" >> "$GITHUB_OUTPUT"
    echo "tarball_path=$OUTPUT_DIR/$TARBALL_NAME" >> "$GITHUB_OUTPUT"
    echo "version=${MAJOR}.${MINOR}${PRERELEASE:+-$PRERELEASE}" >> "$GITHUB_OUTPUT"
fi
