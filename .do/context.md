# Compact at 2026-01-10 15:10:09

## 대화 요약

### 완료된 작업

#### 1. PodoSoju 앱 기능 개선
- **Portable exe 복사 기능**: + 버튼으로 외부 exe 추가 시 workspace/Programs/로 복사
  - `AddProgramView.swift`: isPortable 감지, copyPortableAndAdd() 함수 추가
  - `Workspace.swift`: programsURL, copyPortableProgram() 함수 추가

- **macOS Desktop 접근 방지**: Wine prefix 내 심볼릭 링크 스킵
  - `ShortcutsGridView.swift`: scanDesktopFolders()에서 symlink 체크
  - `DesktopWatcher.swift`: 심볼릭 링크 폴더 제외

- **Wine 창 포커스 개선**: focusRunningProgram() 로직 수정
  - windowName이 nil이어도 Wine PID면 포커스 시도
  - titleMatches일 때만 return true

- **좀비 프로세스 방지**: killAllWineProcesses() 강화
  - CGWindowList에서 Wine 창 소유자 PID 직접 종료
  - portable exe 경로 패턴 추가 (com.podosoju.app)

- **인디케이터 타이밍 개선**:
  - pendingLaunches로 대기 중인 프로그램 추적
  - checkMyWindowOpened()로 정확한 창 감지 시도

#### 2. Wine 수정 프로젝트 시작
- Wine 11.0-rc5 소스 다운로드 완료
- `feature/wine-window-identifier` 브랜치 생성
- `cocoa_window.m` 패치 적용: SOJU_EXE_PATH 환경변수로 NSWindow identifier 설정

### 현재 상태
- **app 브랜치**: main (수정사항 있음, 미커밋)
- **soju 브랜치**: feature/wine-window-identifier

### 핵심 문제
Wine 창이 어떤 exe의 것인지 명시적으로 구분할 수 없음:
- kCGWindowOwnerName: 항상 "wine"
- kCGWindowName: nil인 경우 많음
- 해결책: Wine 수정해서 NSWindow identifier에 exe 경로 저장

### 다음 할 일
1. Wine macOS 빌드 (복잡함 - GitHub Actions 또는 로컬)
2. Soju 빌드 스크립트 수정 (자체 빌드 사용)
3. PodoSoju 앱에서 창 identifier 읽기 구현
4. SOJU_EXE_PATH 환경변수 설정 (Program.run()에서)

### 중요 결정사항
- Wine 자체 빌드로 전환 (Gcenx 바이너리 대신)
- SOJU_EXE_PATH 환경변수로 exe 경로 전달
- NSWindow setIdentifier:로 창 식별

### 주요 파일 변경
**app:**
- `PodoSoju/Views/Creation/AddProgramView.swift`: portable 복사 기능
- `PodoSoju/Views/Workspace/ShortcutView.swift`: 인디케이터 로직 개선
- `PodoSoju/Views/Workspace/ShortcutsGridView.swift`: symlink 스킵
- `PodoSojuKit/.../Models/Workspace.swift`: focusRunningProgram, copyPortableProgram
- `PodoSojuKit/.../Managers/SojuManager.swift`: killAllWineProcesses 강화
- `PodoSojuKit/.../Utilities/DesktopWatcher.swift`: symlink 제외

**soju:**
- `wine-source/wine-11.0-rc5/dlls/winemac.drv/cocoa_window.m`: identifier 패치

---
