<p align="center">
  <img src="assets/icons/app_icon.png" width="160" height="160" alt="AutoCure Logo" style="border-radius: 32px;">
</p>

<h1 align="center">AutoCure</h1>
<p align="center">
  <strong>Self-Healing Flutter Agent</strong><br>
  An autonomous agent that automatically detects, analyzes, and fixes runtime errors in Flutter apps.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11+-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Web-8A2BE2" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

<p align="center">
  <a href="README.ko.md">한국어</a>
</p>

---

## Screenshots

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
    <td align="center"><sub>Notifications</sub></td>
    <td align="center"><sub>Settings</sub></td>
    <td align="center"><sub>Settings Detail</sub></td>
    <td align="center"><sub>Export Menu</sub></td>
  </tr>
</table>

---

## Supported Platforms

| Platform | Supported | Notes |
|----------|:---------:|-------|
| Android | ✅ | Android 5.0 (API 21)+ |
| iOS | ✅ | iOS 12.0+ |
| macOS | ✅ | macOS 10.14+ |
| Linux | ✅ | x64 |
| Windows | ✅ | Windows 10+ |
| Web | ✅ | Chrome, Firefox, Safari, Edge |

---

## Overview

```
Runtime error occurs
    |
    v
[VM Service] Capture error (RenderFlex, Null, setState, etc.)
    |
    v
[ErrorAnalyzer] Root cause analysis + fix strategy selection
    |
    v
[CodeFixer] Apply one of 7 auto-fix strategies
    |
    v
[Verification] Verify with dart analyze + flutter test
    |
    v
  Pass? ──Yes──> [CI/CD] Create PR on autofix/* branch
    |                        |
   No                   GitHub Actions
    |                   analysis/test pass
    v                        |
 Auto-rollback          Auto-merge
```

---

## Architecture

```
lib/
├── core/
│   ├── mcp/                    # MCP server integration
│   │   ├── mcp_server.dart     # JSON-RPC MCP server (widget tree/source access)
│   │   └── widget_inspector.dart # VM Service widget tree inspector
│   ├── self_healing/           # Self-healing engine
│   │   ├── agent.dart          # Main orchestrator
│   │   ├── error_analyzer.dart # Error pattern analysis + root cause tracing
│   │   ├── code_fixer.dart     # 7 auto-fix strategies
│   │   └── verification.dart   # dart analyze + flutter test verification
│   └── vm_service/             # Runtime monitoring
│       ├── vm_connector.dart   # Flutter VM Service connection
│       └── error_stream.dart   # Real-time error stream
├── models/                     # Data models
├── services/                   # Service layer
│   ├── agent_provider.dart     # Flutter UI <-> Agent bridge
│   └── ci_cd_service.dart      # GitHub API + auto PR creation
├── screens/                    # Admin dashboard
├── theme/
│   └── app_theme.dart          # Design system (colors, themes)
└── main.dart                   # App entry point

tools/
└── mcp_server/bin/server.dart  # Standalone MCP server

.github/
└── workflows/
    └── self-heal.yml           # CI/CD auto-merge pipeline
```

---

## Features

### 1. MCP Server Integration

A Dart-based MCP (Model Context Protocol) server provides project access to the agent.

| Tool | Description |
|------|-------------|
| `get_widget_tree` | Inspect the running app's widget tree structure |
| `get_source_code` | Read Dart source files with line numbers |
| `analyze_file` | Run `dart analyze` and return diagnostics |
| `apply_fix` | Auto-fix a specified code region |

### 2. Runtime Monitoring

Connects to a running app via Flutter VM Service Protocol and captures errors in real time:

- **RenderFlex overflowed** - Layout overflow
- **RenderBox was not laid out** - Unlaid render box
- **Null check operator on null value** - Null reference
- **setState() called after dispose()** - setState after dispose
- **Type errors** - Type casting failures

### 3. Self-Healing Workflow

Applies 7 automatic fix strategies based on error patterns:

| Strategy | Target Error | Fix Applied |
|----------|-------------|-------------|
| `WrapWithExpanded` | RenderFlex overflow | Wrap child widget with `Expanded` |
| `WrapWithSingleChildScrollView` | Content overflow | Wrap with `SingleChildScrollView` |
| `AddFlexible` | Flex overflow | Add `Flexible` widget |
| `AddNullCheck` | Null reference | Apply `?.` and null safety |
| `AddMountedCheck` | setState after dispose | Insert `if (!mounted) return;` guard |
| `WrapWithSafeArea` | System UI intrusion | Wrap with `SafeArea` |
| `AddConstraints` | Unbounded size | Add `SizedBox`/`ConstrainedBox` |

After applying a fix, it verifies with `dart analyze` + `flutter test` and auto-rollbacks on failure.

### 4. CI/CD Integration

- Auto-creates `autofix/{error-type}-{timestamp}` branches
- Creates PRs via GitHub API (with error description, root cause, code diff)
- Auto-approves + squash merges on test pass
- Posts failure comment + closes PR on test failure
- Supports external CI webhooks (e.g., Semaphore CI)

### 5. Admin Dashboard

A real-time monitoring dashboard available on mobile, desktop, and web:

- **Overview tab** - Agent status, error/fix/verified/PR counts, success rate chart
- **Timeline tab** - Chronological view of error and fix events
- **Errors tab** - Live error log (severity, stack trace, widget path)
- **Fixes tab** - Fix history (original/fixed code diff, test results, PR links)
- **Notifications** - Real-time alerts (error detected, fix applied, PR created)
- **Settings** - VM Service connection, GitHub/CI config, agent behavior, notification settings

### 6. Design System

Custom color palette with a unified design system:

| Usage | Color | Hex |
|-------|-------|-----|
| Primary | Purple | `#6C5CE7` |
| Accent | Cyan | `#00D2D3` |
| Success | Mint Green | `#00B894` |
| Warning | Soft Orange | `#FDAA5E` |
| Error | Coral Red | `#FF6B6B` |
| Info | Sky Blue | `#54A0FF` |

Full light/dark mode support, gradient bar charts, glowing timeline effects, and modern UI throughout.

---

## Usage

### Step 1: Installation

```bash
git clone https://github.com/kimdzhekhon/Auto_Cure.git
cd Auto_Cure
flutter pub get
```

### Step 2: Run the AutoCure Dashboard

```bash
flutter run              # Mobile
flutter run -d macos     # macOS
flutter run -d windows   # Windows
flutter run -d linux     # Linux
flutter run -d chrome    # Web
```

### Step 3: Connect to a Target Flutter App

```bash
cd /path/to/your/flutter/app
flutter run --debug
```

Find the VM Service URI in the terminal output:

```
An Observatory debugger and profiler on ... is available at:
http://127.0.0.1:XXXXX/XXXXXX=/
```

Tap **Start Agent** in the AutoCure dashboard and enter the URI.

### Step 4: Enable Auto-Healing

1. Turn on the **Agent ON/OFF toggle** in the dashboard.
2. The agent starts monitoring the target app's runtime errors in real time.
3. When an error occurs, it automatically analyzes, fixes, verifies, and creates a PR.

### Step 5: MCP Server (Optional)

```bash
dart run tools/mcp_server/bin/server.dart
```

### Step 6: CI/CD Setup (Optional)

```bash
export GITHUB_TOKEN=your_token
export AUTOCURE_REPO_OWNER=kimdzhekhon
export AUTOCURE_REPO_NAME=Auto_Cure
```

---

## Tech Stack

| Area | Technology |
|------|-----------|
| Framework | Flutter 3.11+ / Dart 3.11+ |
| Runtime Monitoring | `vm_service`, `web_socket_channel` |
| State Management | `provider` |
| Charts | `fl_chart` |
| CI/CD | GitHub Actions, GitHub API |
| MCP Communication | JSON-RPC 2.0 over stdin/stdout |
| Process Management | `process_run` |

---

## License

This project is licensed under the MIT License.
