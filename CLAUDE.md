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
    - `/home`, `/input`, `/calendar`, `/analysis`, `/settings`
- `ShellScreen` wraps tabs with `PageView` + `PageController` (`jumpToPage`, `ClampingScrollPhysics`)
- Tab pages use `NoTransitionPage`; push navigation uses platform transitions (Cupertino/FadeUpwards)

### Data Flow
- `main()` calls `StorageService().init()` → `dotenv.load()` → `Supabase.initialize()` before `runApp`
- Screens call `StorageService` directly (no global state management; `provider` is a dependency but unused)
- `AiService` calls Gemini API (`gemini-3.5-flash`) via `http` package with `?key=` query param auth

### Key Conventions
- **Supabase column names are snake_case**: `Budget.fromJson()` reads snake_case keys (`savings_goal`, `category_budgets`, etc.). `StorageService.saveBudget()` manually maps to snake_case on insert.
- `user_id` is hardcoded as `'local_user'` — no auth yet.
- Category set: `식비 / 술 / 교통 / 카페 / 쇼핑 / 기타` (지출), `알바 / 용돈 / 기타수입` (수입)
- Branch policy: feature branches → `develop` only. Never merge directly to `main`.

## Tech Stack

| Layer | Package |
|---|---|
| Routing | go_router ^14.8.1 |
| Backend | supabase_flutter ^2.8.4 |
| AI | http ^1.4.0 → Gemini API |
| Env vars | flutter_dotenv ^5.2.1 |
| Formatting | intl ^0.20.2 |
| IDs | uuid ^4.5.1 |
| Notifications | flutter_local_notifications ^18.0.1 |
| Calendar | table_calendar |

## Environment

`.env` is gitignored. Required keys:
```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
GEMINI_API_KEY=...
```

`.env` is registered in `pubspec.yaml` under `flutter.assets`.

## Design System

모든 색상은 `lib/constants/app_colors.dart`의 `AppColors`에서 관리한다. 화면에 직접 `Color(0xFF...)` 리터럴을 쓰지 않는다.

| 상수 | 값 | 용도 |
|---|---|---|
| `AppColors.primary` | `0xFF1D9E75` | 주 색상 (초록) |
| `AppColors.warning` | `0xFFEF9F27` | 경고 (주황) |
| `AppColors.danger` | `0xFFE24B4A` | 위험 (빨강) |
| `AppColors.surface` | `0xFFF8F8FA` | Scaffold 배경 |
| `AppColors.primaryLight` | `0xFFE1F5EE` | 칩 선택 배경, 아이콘 배경 |
| `AppColors.dangerLight` | `0xFFFCEBEB` | 초과 카테고리 카드 배경 |
| `AppColors.warningBg` | `0xFFFFF3E0` | AI 경고 카드 배경 |
| `AppColors.divider` | `0xFFF0F0F0` | 구분선, 탭 셀렉터 배경 |
| `AppColors.border` | `0xFFEEEEEE` | TextField 테두리 |
| `AppColors.chipUnselected` | `0xFFF5F5F5` | 미선택 칩 배경 |
| `AppColors.textHint` | `0xFF999999` | 힌트 텍스트 |

- TextField: `OutlineInputBorder`, `borderRadius 16`, `filled: true`, `fillColor: white`
- Cards: `borderRadius 12–16`, white background
- Primary button: `height 52`, `borderRadius 12`, full width

## Constants & Shared Utilities

| 파일 | 내용 |
|---|---|
| `lib/constants/app_colors.dart` | `AppColors` — 모든 Color 상수 |
| `lib/constants/app_strings.dart` | `AppStrings` — 공통 한국어 문자열 (버튼 레이블, 오류 메시지) |
| `lib/constants/app_categories.dart` | `AppCategories` — 지출/수입 카테고리 목록, `warningCategories` |
| `lib/utils/format.dart` | `formatNumber(int n)` — 쉼표 포맷 |
| `lib/utils/category.dart` | `categoryList`, `categoryEmoji()`, `incomeEmoji()`, `progressColor()` |

`category.dart`는 `app_categories.dart`를 re-export하므로 `cat.categoryList` 형태로 접근 가능.

## Shared Widgets

| 위젯 | 파일 | 설명 |
|---|---|---|
| `AppToast` | `widgets/app_toast.dart` | 슬라이드 인/아웃 토스트 메시지 |
| `AppTabSelector` | `widgets/app_tab_selector.dart` | 지출/수입 탭 선택기 (InputScreen, AnalysisScreen 공용) |
| `CategoryCard` | `widgets/category_card.dart` | 홈 카테고리별 지출 카드 |
| `BudgetSummaryCard` | `widgets/budget_summary_card.dart` | 분석 화면 총 지출/저축 달성률 카드 |
| `AppCard` | `widgets/common_card.dart` | 공통 흰 배경 카드 컨테이너 |

## AiService 패턴

- `lib/services/ai_service.dart` — 싱글톤
- Gemini 엔드포인트: `v1beta/models/gemini-3.5-flash:generateContent?key=...`
- 모든 요청에 `thinkingConfig: {thinkingBudget: 0}` 포함
- AI 실패 시 키워드 기반 fallback (`_fallbackClassify`, `_fallbackClassifyIncome`)
- AI 분류 debounce: 800ms + generation counter (race condition 방지)

## Screen Status

| Screen | Status |
|---|---|
| OnboardingScreen | 완성 — 수입/저축 입력, AI 예산 생성, 자동 이월 설정 |
| HomeScreen | 완성 — 실지출 연결, refreshTrigger 패턴, AI 예산 경고 카드 |
| InputScreen | 완성 — AI 분류(debounce 800ms), 지출/수입 탭, Supabase 저장 |
| CalendarScreen | 완성 — 월별 달력, 일별 지출/수입 내역, 수정/삭제 |
| AnalysisScreen | 완성 — 실데이터 연결, AI 월간 리포트, 저축 달성률 |
| SettingsScreen | 완성 — 예산 재설정, 자동이월 토글, 지출 초기화, Pro 구독 |
| ShellScreen | 완성 — PageView 탭 관리, 탭 전환 시 HomeScreen refresh |
