# Podo-Soju

**Soju-Wine 11.0-rc4 패키징 저장소**

Gcenx Wine-Staging 11.0-rc4 + Apple D3DMetal을 Whisky 호환 tarball로 패키징하는 자동화 스크립트

## 소개

Soju-Wine은 다음을 통합합니다:

- **Wine-Staging 11.0-rc4** (Gcenx macOS 빌드)
- **D3DMetal** (Apple Game Porting Toolkit의 Metal 기반 Direct3D 구현)
- **Whisky 호환 구조** (SemanticVersion 메타데이터 포함)

## 빌드 방법

### 사전 요구사항

- macOS (Intel 또는 Apple Silicon)
- Xcode Command Line Tools
- Apple Game Porting Toolkit (D3DMetal 필요 시)

### 빌드 실행

```bash
# 저장소 클론
git clone https://github.com/yejune/podo-soju.git
cd podo-soju

# 패키징 스크립트 실행
./scripts/package.sh
```

스크립트는 자동으로:
1. Wine-Staging 11.0-rc4 다운로드 (없을 경우)
2. Gcenx Wine 바이너리 복사
3. D3DMetal 프레임워크 통합 (GPTK 설치 시)
4. SojuWineVersion.plist 생성 (버전 메타데이터)
5. tarball 생성: `dist/SojuWine-11.0-rc4.tar.gz`

## 설치 방법

### Whisky에 설치

```bash
# tarball 압축 해제
tar -xzf dist/SojuWine-11.0-rc4.tar.gz -C ~/Library/Application\ Support/com.isaacmarovitz.Whisky/

# Whisky 재시작
# 설정 → Wine 버전에서 "Soju-Wine 11.0-rc4" 선택
```

### 수동 설치 (테스트용)

```bash
# 특정 디렉토리에 압축 해제
tar -xzf dist/SojuWine-11.0-rc4.tar.gz -C /path/to/install

# Wine 실행 테스트
/path/to/install/Libraries/Wine/bin/wine --version
```

## 빌드 구조

```
dist/
└── SojuWine-11.0-rc4.tar.gz
    └── Libraries/
        ├── SojuWineVersion.plist       # 버전 메타데이터
        └── Wine/
            ├── bin/                     # wine, wineserver 등
            ├── lib/
            │   ├── wine/                # Wine 라이브러리
            │   └── external/
            │       ├── D3DMetal.framework
            │       └── libd3dshared.dylib
            └── share/                   # Wine 리소스
```

## 버전 정보

- **Wine 버전**: 11.0-rc4 (Staging)
- **D3DMetal**: Apple GPTK (설치 시)
- **플랫폼**: macOS x86_64 (Rosetta 2 지원)

## 라이선스

- Wine: LGPL 2.1+
- D3DMetal: Apple GPTK 라이선스
- 이 스크립트: MIT

## 참고

- [Gcenx Wine 빌드](https://github.com/Gcenx/macOS_Wine_builds)
- [Whisky](https://github.com/Whisky-App/Whisky)
- [Apple Game Porting Toolkit](https://developer.apple.com/games/)
