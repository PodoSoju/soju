# Soju

**Wine distribution for PodoSoju**

Wine-Staging with DXMT and DXVK for macOS. This Wine distribution is used by the [PodoSoju](https://github.com/podo-os/PodoSoju) app to run Windows applications.

## Features

- **Wine-Staging 11.0-rc4** (Gcenx macOS build)
- **DXMT** - DirectX 10/11 to Metal translation (MIT license)
- **DXVK** - DirectX 9-11 to Vulkan/MoltenVK translation
- **CJK Fonts** - Korean, Japanese, Chinese font support

## Installation

Soju is automatically downloaded by the PodoSoju app on first launch. No manual installation required.

### Manual Download

Download from [GitHub Releases](https://github.com/PodoSoju/soju/releases/latest).

```bash
# Extract to Soju's Libraries directory
tar -xzf Soju-*.tar.gz -C ~/Library/Application\ Support/com.soju.app/
```

## Building

### Prerequisites

- macOS (Apple Silicon or Intel)
- Xcode Command Line Tools

### Build Script

```bash
git clone https://github.com/PodoSoju/soju.git
cd soju
./scripts/package.sh
```

The script will:
1. Download Wine-Staging from Gcenx
2. Download DXMT and DXVK
3. Bundle CJK fonts
4. Create tarball in `dist/`

### GitHub Actions

Releases are automatically built when a version tag is pushed:

```bash
git tag v11.0-rc4
git push origin v11.0-rc4
```

## Package Structure

```
Libraries/
├── Soju/
│   ├── bin/           # wine, wineserver, etc.
│   ├── lib/
│   │   ├── wine/      # Wine libraries
│   │   └── external/  # DXMT, DXVK
│   └── share/         # Resources, fonts
└── SojuVersion.plist
```

## Graphics Backends

| Backend | DirectX Support | License |
|---------|-----------------|---------|
| DXMT | DX10, DX11 | MIT |
| DXVK | DX9, DX10, DX11 | zlib |
| D3DMetal | DX11, DX12 | Apple (requires GPTK) |

D3DMetal is not included due to licensing. Users can install Apple's Game Porting Toolkit separately for DX12 support.

## License

- Wine: LGPL 2.1+
- DXMT: MIT
- DXVK: zlib
- Packaging scripts: MIT

## References

- [Gcenx Wine Builds](https://github.com/Gcenx/macOS_Wine_builds)
- [DXMT](https://github.com/3Shain/dxmt)
- [DXVK](https://github.com/doitsujin/dxvk)
- [WhiskyWine](https://github.com/Whisky-App/WhiskyWine)
- [PodoSoju App](https://github.com/PodoSoju/app)
