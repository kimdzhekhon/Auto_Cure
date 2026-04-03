# AutoCure - Self-Healing Flutter Agent

Flutter 앱의 런타임 오류를 자동으로 탐지하고, 분석하고, 코드를 수정하는 **자율 복구(Self-Healing)** 관리 에이전트 시스템입니다.

---

## Overview

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

## Architecture

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
│   └── dashboard/
│       ├── dashboard_screen.dart
│       └── widgets/
│           ├── status_card.dart
│           ├── agent_status_widget.dart
│           ├── error_log_view.dart
│           ├── fix_history_list.dart
│           └── stats_chart.dart
└── main.dart                   # 앱 엔트리포인트

tools/
└── mcp_server/bin/server.dart  # 독립 실행 MCP 서버

.github/
└── workflows/
    └── self-heal.yml           # CI/CD 자동 머지 파이프라인
```

---

## Features

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

모바일 앱에서 실시간으로 모니터링할 수 있는 관리자 화면:

- **Overview 탭** - 에러 탐지 수, 수정 수, 검증 수, PR 수 + 성공률 차트
- **Errors 탭** - 실시간 에러 로그 (심각도, 스택 트레이스, 위젯 경로)
- **Fix History 탭** - 수정 이력 (원본/수정 코드 diff, 테스트 결과, PR 링크)
- VM Service 연결 상태 + MCP 서버 상태 실시간 표시
- 에이전트 ON/OFF 토글 + VM Service URI 연결 다이얼로그

---

## Getting Started

### Prerequisites

- Flutter SDK >= 3.11.1
- Dart SDK >= 3.11.1
- Git

### Installation

```bash
# 프로젝트 클론
git clone https://github.com/kimdzhekhon/Auto_Cure.git
cd Auto_Cure

# 의존성 설치
flutter pub get

# 앱 실행
flutter run
```

### VM Service 연결

```bash
# 1. 대상 Flutter 앱을 디버그 모드로 실행
flutter run --debug

# 2. 출력에서 VM service URI 확인
# An Observatory debugger and profiler on ... is available at:
# http://127.0.0.1:XXXXX/XXXXXX=/

# 3. AutoCure 대시보드에서 해당 URI로 연결
```

### CI/CD 설정

GitHub Actions 사용 시 추가 설정 없이 `autofix/*` 브랜치 푸시 시 자동 실행됩니다.

GitHub API를 통한 PR 생성 시 환경변수 설정:

```bash
export GITHUB_TOKEN=your_token
export AUTOCURE_REPO_OWNER=kimdzhekhon
export AUTOCURE_REPO_NAME=Auto_Cure
```

---

## Tech Stack

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

## License

This project is licensed under the MIT License.
