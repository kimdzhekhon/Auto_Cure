<p align="center">
  <img src="assets/icons/app_icon.png" width="160" height="160" alt="AutoCure Logo" style="border-radius: 32px;">
</p>

<h1 align="center">AutoCure</h1>
<p align="center">
  <strong>Self-Healing Flutter Agent</strong><br>
  Flutter 앱의 런타임 오류를 자동으로 탐지 · 분석 · 수정하는 자율 복구 에이전트
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11+-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Web-8A2BE2" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

<p align="center">
  <a href="README.md">English</a>
</p>

---

## 스크린샷

<table>
  <tr>
    <td><img src="assets/screen/01_overview.png" width="200" alt="Overview"></td>
    <td><img src="assets/screen/02_timeline.png" width="200" alt="Timeline"></td>
    <td><img src="assets/screen/03_errors.png" width="200" alt="Errors"></td>
    <td><img src="assets/screen/04_fixes.png" width="200" alt="Fixes"></td>
  </tr>
  <tr>
    <td align="center"><sub>Overview</sub></td>
    <td align="center"><sub>Timeline</sub></td>
    <td align="center"><sub>Errors</sub></td>
    <td align="center"><sub>Fixes</sub></td>
  </tr>
  <tr>
    <td><img src="assets/screen/05_notifications.png" width="200" alt="Notifications"></td>
    <td><img src="assets/screen/06_settings_top.png" width="200" alt="Settings"></td>
    <td><img src="assets/screen/07_settings_bottom.png" width="200" alt="Settings Detail"></td>
    <td><img src="assets/screen/08_menu.png" width="200" alt="Menu"></td>
  </tr>
  <tr>
    <td align="center"><sub>알림</sub></td>
    <td align="center"><sub>설정</sub></td>
    <td align="center"><sub>설정 상세</sub></td>
    <td align="center"><sub>내보내기 메뉴</sub></td>
  </tr>
</table>

---

## 지원 플랫폼

| 플랫폼 | 지원 | 비고 |
|--------|:----:|------|
| Android | ✅ | Android 5.0 (API 21) 이상 |
| iOS | ✅ | iOS 12.0 이상 |
| macOS | ✅ | macOS 10.14 이상 |
| Linux | ✅ | x64 |
| Windows | ✅ | Windows 10 이상 |
| Web | ✅ | Chrome, Firefox, Safari, Edge |

---

## 개요

```
런타임 에러 발생
    |
    v
[VM Service] 에러 캡처 (RenderFlex, Null, setState 등)
    |
    v
[ErrorAnalyzer] 루트 원인 분석 + 수정 전략 결정
    |
    v
[CodeFixer] 7가지 자동 수정 전략 적용
    |
    v
[Verification] dart analyze + flutter test 검증
    |
    v
  통과? ──Yes──> [CI/CD] autofix/* 브랜치 PR 생성
    |                        |
   No                   GitHub Actions
    |                   분석/테스트 통과
    v                        |
 자동 롤백               자동 머지
```

---

## 아키텍처

```
lib/
├── core/
│   ├── mcp/                    # MCP 서버 연동
│   │   ├── mcp_server.dart     # JSON-RPC MCP 서버 (위젯 트리/소스 접근)
│   │   └── widget_inspector.dart # VM Service 위젯 트리 인스펙터
│   ├── self_healing/           # 자가 치유 엔진
│   │   ├── agent.dart          # 메인 오케스트레이터
│   │   ├── error_analyzer.dart # 에러 패턴 분석 + 루트 원인 추적
│   │   ├── code_fixer.dart     # 7가지 자동 수정 전략
│   │   └── verification.dart   # dart analyze + flutter test 검증
│   └── vm_service/             # 런타임 감시
│       ├── vm_connector.dart   # Flutter VM Service 연결
│       └── error_stream.dart   # 실시간 에러 스트림
├── models/                     # 데이터 모델
│   ├── error_report.dart       # 에러 리포트
│   ├── fix_record.dart         # 수정 기록
│   └── agent_status.dart       # 에이전트 상태
├── services/                   # 서비스 레이어
│   ├── agent_provider.dart     # Flutter UI <-> Agent 브릿지
│   └── ci_cd_service.dart      # GitHub API + PR 자동 생성
├── screens/                    # 관리자 대시보드
│   ├── dashboard/
│   │   ├── dashboard_screen.dart
│   │   └── widgets/
│   │       ├── status_card.dart
│   │       ├── agent_status_widget.dart
│   │       ├── error_log_view.dart
│   │       ├── fix_history_list.dart
│   │       ├── stats_chart.dart
│   │       ├── timeline_view.dart
│   │       └── notification_bell.dart
│   └── settings/
│       └── settings_screen.dart
├── theme/
│   └── app_theme.dart          # 디자인 시스템 (컬러, 테마)
└── main.dart                   # 앱 엔트리포인트

tools/
└── mcp_server/bin/server.dart  # 독립 실행 MCP 서버

.github/
└── workflows/
    └── self-heal.yml           # CI/CD 자동 머지 파이프라인
```

---

## 주요 기능

### 1. MCP 서버 연동

Dart 기반 MCP(Model Context Protocol) 서버가 에이전트에게 프로젝트 접근 권한을 제공합니다.

| Tool | 설명 |
|------|------|
| `get_widget_tree` | 실행 중인 앱의 위젯 트리 구조 조회 |
| `get_source_code` | Dart 소스 파일 라인 번호 포함 읽기 |
| `analyze_file` | `dart analyze` 실행 및 진단 결과 반환 |
| `apply_fix` | 지정된 코드 영역 자동 수정 |

```bash
# 독립 실행 MCP 서버 시작
dart run tools/mcp_server/bin/server.dart
```

### 2. 런타임 감시

Flutter VM Service Protocol을 통해 실행 중인 앱에 연결하고, 다음 에러들을 실시간으로 캡처합니다:

- **RenderFlex overflowed** - 레이아웃 오버플로우
- **RenderBox was not laid out** - 미배치 렌더 박스
- **Null check operator on null value** - 널 참조
- **setState() called after dispose()** - dispose 이후 setState
- **Type errors** - 타입 캐스팅 실패

### 3. 자가 치유 워크플로우

에러 패턴에 따라 7가지 자동 수정 전략을 적용합니다:

| 전략 | 대상 에러 | 수정 내용 |
|------|----------|----------|
| `WrapWithExpanded` | RenderFlex overflow | 자식 위젯을 `Expanded`로 감싸기 |
| `WrapWithSingleChildScrollView` | 콘텐츠 오버플로우 | `SingleChildScrollView` 래핑 |
| `AddFlexible` | Flex 오버플로우 | `Flexible` 위젯 추가 |
| `AddNullCheck` | Null 참조 | `?.` 및 null safety 적용 |
| `AddMountedCheck` | setState after dispose | `if (!mounted) return;` 가드 삽입 |
| `WrapWithSafeArea` | 시스템 UI 침범 | `SafeArea` 래핑 |
| `AddConstraints` | 무제한 크기 | `SizedBox`/`ConstrainedBox` 추가 |

수정 후 `dart analyze` + `flutter test`로 검증하며, 실패 시 자동 롤백합니다.

### 4. CI/CD 통합

```yaml
# 자동 트리거: autofix/* 브랜치 푸시 시
# 수동 트리거: workflow_dispatch
# 스케줄: 매일 03:00 UTC

analyze → test → auto-merge (성공) / close PR (실패)
```

- `autofix/{error-type}-{timestamp}` 브랜치 자동 생성
- GitHub API를 통한 PR 생성 (에러 설명, 루트 원인, 코드 diff 포함)
- 테스트 통과 시 자동 승인 + squash 머지
- 테스트 실패 시 실패 코멘트 + PR 자동 닫기
- Semaphore CI 등 외부 CI webhook 지원

### 5. 관리자 대시보드

모바일/데스크탑/웹에서 실시간으로 모니터링할 수 있는 관리자 화면:

- **Overview 탭** - 에이전트 상태, 에러/수정/검증/PR 카운트, 성공률 차트
- **Timeline 탭** - 에러와 수정 이벤트를 시간순으로 표시
- **Errors 탭** - 실시간 에러 로그 (심각도, 스택 트레이스, 위젯 경로)
- **Fixes 탭** - 수정 이력 (원본/수정 코드 diff, 테스트 결과, PR 링크)
- **Notifications** - 실시간 알림 (에러 탐지, 수정 완료, PR 생성 등)
- **Settings** - VM Service 연결, GitHub/CI 설정, 에이전트 동작 설정, 알림 설정

### 6. 디자인 시스템

커스텀 컬러 팔레트와 통일된 디자인 시스템을 적용했습니다:

| 용도 | 컬러 | Hex |
|------|------|-----|
| Primary | 퍼플 | `#6C5CE7` |
| Accent | 시안 | `#00D2D3` |
| Success | 민트 그린 | `#00B894` |
| Warning | 소프트 오렌지 | `#FDAA5E` |
| Error | 코랄 레드 | `#FF6B6B` |
| Info | 스카이 블루 | `#54A0FF` |

라이트/다크 모드 완전 지원, 그라데이션 바 차트, 글로우 효과 타임라인 등 모던 UI를 제공합니다.

---

## 사용 방법

### 1단계: 설치

```bash
git clone https://github.com/kimdzhekhon/Auto_Cure.git
cd Auto_Cure
flutter pub get
```

### 2단계: AutoCure 대시보드 실행

```bash
flutter run              # 모바일
flutter run -d macos     # macOS
flutter run -d windows   # Windows
flutter run -d linux     # Linux
flutter run -d chrome    # 웹
```

### 3단계: 대상 Flutter 앱과 연결

```bash
cd /path/to/your/flutter/app
flutter run --debug
```

터미널 출력에서 VM Service URI를 확인합니다:

```
An Observatory debugger and profiler on ... is available at:
http://127.0.0.1:XXXXX/XXXXXX=/
```

AutoCure 대시보드의 **Start Agent** 버튼을 탭하고 URI를 입력하면 연결됩니다.

### 4단계: 자동 복구 활성화

1. 대시보드에서 **Agent ON/OFF 토글**을 켭니다.
2. 에이전트가 대상 앱의 런타임 에러를 실시간으로 감시합니다.
3. 에러 발생 시 자동으로 분석 → 수정 → 검증 → PR 생성까지 진행합니다.

### 5단계: MCP 서버 (선택사항)

```bash
dart run tools/mcp_server/bin/server.dart
```

### 6단계: CI/CD 설정 (선택사항)

```bash
export GITHUB_TOKEN=your_token
export AUTOCURE_REPO_OWNER=kimdzhekhon
export AUTOCURE_REPO_NAME=Auto_Cure
```

---

## 기술 스택

| 영역 | 기술 |
|------|------|
| Framework | Flutter 3.11+ / Dart 3.11+ |
| 런타임 감시 | `vm_service`, `web_socket_channel` |
| 상태 관리 | `provider` |
| 차트 | `fl_chart` |
| CI/CD | GitHub Actions, GitHub API |
| MCP 통신 | JSON-RPC 2.0 over stdin/stdout |
| 프로세스 관리 | `process_run` |

---

## 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다.
