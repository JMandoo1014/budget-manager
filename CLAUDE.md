# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app (connect a device or simulator first)
flutter run

# Run on a specific device
flutter run -d <device-id>          # e.g. -d ios, -d android
flutter devices                     # list available devices

# Build
flutter build apk                   # Android APK
flutter build ios                   # iOS (requires macOS + Xcode)

# Test
flutter test                        # run all tests
flutter test test/widget_test.dart  # run a single test file

# Lint / static analysis
flutter analyze

# Upgrade dependencies
flutter pub upgrade
```

## Architecture

### Routing (main.dart)
- `GoRouter` with two-level structure:
  - `/` → `OnboardingScreen` (standalone route)
  - `StatefulShellRoute.indexedStack` for tab screens:
    - `/home`, `/input`, `/analysis`, `/settings`
- `ShellScreen` wraps tabs with `PageView` + `PageController` (`jumpToPage`, `ClampingScrollPhysics`)
- Tab pages use `NoTransitionPage`; push navigation uses platform transitions (Cupertino/FadeUpwards)

### Data Flow
- `main()` calls `StorageService().init()` → `dotenv.load()` → `Supabase.initialize()` before `runApp`
- Screens call `StorageService` directly (no global state management yet; `provider` is a dependency but unused)
- `AiService` calls Claude API (`claude-sonnet-4-20250514`) via `http` package

### Key Conventions
- **Supabase column names are snake_case**: `Budget.fromJson()` reads snake_case keys (`savings_goal`, `category_budgets`, etc.). `Budget.toJson()` uses camelCase (local only). `StorageService.saveBudget()` manually maps to snake_case on insert.
- `user_id` is hardcoded as `'local_user'` — no auth yet.
- Category set: `식비 / 술 / 교통 / 카페 / 쇼핑 / 기타`

## Tech Stack

| Layer | Package |
|---|---|
| Routing | go_router ^14.8.1 |
| Backend | supabase_flutter ^2.8.4 |
| AI | http ^1.4.0 → Claude API |
| Env vars | flutter_dotenv ^5.2.1 |
| Formatting | intl ^0.20.2 |
| IDs | uuid ^4.5.1 |
| Notifications | flutter_local_notifications ^18.0.1 |
| State (준비) | provider ^6.1.5 |

## Environment

`.env` is gitignored. Required keys:
```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
```
Also add `CLAUDE_API_KEY` to `.env` (loaded via `dotenv.env['CLAUDE_API_KEY']` in `AiService`).

`.env` is registered in `pubspec.yaml` under `flutter.assets`.

## Design System

- **Primary**: `Color(0xFF534AB7)` (보라)
- **Success**: `Color(0xFF1D9E75)` (초록)
- **Warning**: `Color(0xFFEF9F27)` (주황)
- **Danger**: `Color(0xFFE24B4A)` (빨강)
- **Surface**: `Color(0xFFF8F8FA)`
- **Chip selected bg**: `Color(0xFFEEEDFE)`
- TextField: `OutlineInputBorder`, `borderRadius 16`, `filled: true`, `fillColor: white`
- Cards: `borderRadius 12–16`, white background
- Primary button: `height 52`, `borderRadius 12`, full width

## Shared Utilities

- `lib/utils/format.dart` — `formatNumber(int n)` (comma-separated, used in all screens)
- `lib/utils/category.dart` — `categoryMeta`, `categoryList`, `categoryEmoji()`, `progressColor()` (shared across HomeScreen, InputScreen)

## Screen Status

| Screen | Status |
|---|---|
| OnboardingScreen | 완성 |
| HomeScreen | 완성 — 실지출 연결, refreshTrigger 패턴 |
| InputScreen | 완성 — AI 분류(debounce 800ms) + Supabase 저장 |
| AnalysisScreen | 완성 — 실데이터 연결, 저축 달성률 월별 목표 기준 |
| SettingsScreen | 완성 — 예산 재설정, 자동이월 토글, 지출 초기화 |
| ShellScreen | 완성 — PageView 탭 관리 |
