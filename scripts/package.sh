#!/bin/bash
# Gcenx Wine-Staging을 Soju용으로 패키징 (멱등성)
#
# 사용법:
#   ./scripts/package.sh
#
# 자동으로 다운로드, 압축해제, 패키징까지 수행
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WINE_ROOT="$(dirname "$SCRIPT_DIR")"
WINE_STAGING_DIR="$HOME/Work/wine-staging"
GCENX_WINE="$WINE_STAGING_DIR/Contents/Resources/wine"
GPTK_WINE="/Applications/Game Porting Toolkit.app/Contents/Resources/wine"
OUTPUT_DIR="$WINE_ROOT/dist"

# Wine-Staging 버전 설정
WINE_VERSION="11.0-rc4"
WINE_URL="https://github.com/Gcenx/macOS_Wine_builds/releases/download/${WINE_VERSION}/wine-staging-${WINE_VERSION}-osx64.tar.xz"

echo "============================================"
echo "Gcenx Wine-Staging → Soju 패키징"
echo "============================================"
echo ""

# Gcenx Wine 다운로드 (없으면)
if [ ! -f "$GCENX_WINE/bin/wine" ]; then
    echo "[0/4] Wine-Staging ${WINE_VERSION} 다운로드 중..."

    # 다운로드
    curl -L -o /tmp/wine-staging.tar.xz "$WINE_URL"

    # 압축 해제
    rm -rf "$WINE_STAGING_DIR"
    mkdir -p "$WINE_STAGING_DIR"
    tar -xJf /tmp/wine-staging.tar.xz -C "$WINE_STAGING_DIR" --strip-components=1

    # 실행 권한
    chmod +x "$GCENX_WINE/bin/"*
    chmod +x "$WINE_STAGING_DIR/Contents/MacOS/"* 2>/dev/null || true

    # 정리
    rm -f /tmp/wine-staging.tar.xz
    echo "  다운로드 완료!"
    echo ""
fi

# Wine 버전 확인
WINE_VERSION=$(arch -x86_64 "$GCENX_WINE/bin/wine" --version 2>/dev/null | head -1)
echo "Wine 버전: $WINE_VERSION"

# 출력 디렉토리 생성
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/Libraries/Soju"

echo ""
echo "[1/4] Gcenx Wine 복사..."
cp -R "$GCENX_WINE/bin" "$OUTPUT_DIR/Libraries/Soju/"
cp -R "$GCENX_WINE/lib" "$OUTPUT_DIR/Libraries/Soju/"
cp -R "$GCENX_WINE/share" "$OUTPUT_DIR/Libraries/Soju/"

# 실행 권한 확인
chmod +x "$OUTPUT_DIR/Libraries/Soju/bin/"*

echo "[2/5] CJK 폰트 복사..."
FONTS_DIR="$WINE_ROOT/fonts"
if [ -d "$FONTS_DIR" ]; then
    mkdir -p "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts"
    cp "$FONTS_DIR"/*.TTC "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts/" 2>/dev/null || true
    cp "$FONTS_DIR"/*.ttc "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts/" 2>/dev/null || true
    cp "$FONTS_DIR"/OFL-*.txt "$OUTPUT_DIR/Libraries/Soju/share/wine/fonts/" 2>/dev/null || true
    echo "  CJK 폰트 추가됨"
else
    echo "  fonts 폴더 없음"
fi

echo "[3/5] D3DMetal 복사 (GPTK)..."
if [ -d "$GPTK_WINE/lib/external/D3DMetal.framework" ]; then
    mkdir -p "$OUTPUT_DIR/Libraries/Soju/lib/external"
    cp -R "$GPTK_WINE/lib/external/D3DMetal.framework" "$OUTPUT_DIR/Libraries/Soju/lib/external/"
    cp "$GPTK_WINE/lib/external/libd3dshared.dylib" "$OUTPUT_DIR/Libraries/Soju/lib/external/" 2>/dev/null || true
    echo "  D3DMetal 추가됨"
else
    echo "  D3DMetal 없음 (GPTK 미설치)"
fi

echo "[4/5] 버전 정보 생성..."
# Wine 버전 파싱 (예: wine-11.0-rc4 (Staging) → 11.0.0-rc4+staging)
WINE_VER_RAW=$(arch -x86_64 "$GCENX_WINE/bin/wine" --version 2>/dev/null)
# wine-11.0-rc4 (Staging) 형식 파싱
MAJOR=$(echo "$WINE_VER_RAW" | sed -E 's/wine-([0-9]+)\..*/\1/')
MINOR=$(echo "$WINE_VER_RAW" | sed -E 's/wine-[0-9]+\.([0-9]+).*/\1/')
# rc 버전 추출 (없으면 빈 문자열)
PRERELEASE=$(echo "$WINE_VER_RAW" | sed -E 's/.*-(rc[0-9]+).*/\1/' | grep -E '^rc' || echo "")
# Staging 여부
BUILD=$(echo "$WINE_VER_RAW" | grep -i staging >/dev/null && echo "staging" || echo "")
# patch는 항상 0 (rc는 preRelease로 표현)
PATCH="0"

echo "  Soju 버전: $MAJOR.$MINOR-$PRERELEASE ($BUILD)"

# SojuVersion.plist 생성 (SemanticVersion 형식)
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

echo "[5/5] tarball 생성..."
cd "$OUTPUT_DIR"
# 버전명: 11.0-rc4 형식
if [ -n "$PRERELEASE" ]; then
    TARBALL_NAME="Soju-${MAJOR}.${MINOR}-${PRERELEASE}.tar.gz"
else
    TARBALL_NAME="Soju-${MAJOR}.${MINOR}.${PATCH}.tar.gz"
fi
tar -czf "$TARBALL_NAME" Libraries
rm -rf Libraries

echo ""
echo "============================================"
echo "완료: $OUTPUT_DIR/$TARBALL_NAME"
echo "============================================"
echo ""
echo "설치:"
echo "  tar -xzf $TARBALL_NAME -C ~/Library/Application\ Support/com.isaacmarovitz.Whisky/"
