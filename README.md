# 예산 관리 앱 (Budget Manager)

AI 기반 개인 예산 관리 Flutter 앱입니다. 지출/수입 기록, 카테고리 자동 분류, 월간 AI 리포트 등을 제공합니다.

## 주요 기능

- **지출/수입 입력**: AI가 메모를 분석해 카테고리 자동 분류 (debounce 800ms)
- **홈 화면**: 이번 달 카테고리별 지출 현황 및 AI 예산 경고 카드
- **캘린더**: 일별 지출/수입 내역 조회, 수정, 삭제
- **분석**: 월간 지출 분석 및 AI 리포트, 저축 달성률
- **설정**: 예산 재설정, 자동이월 토글, 지출 초기화, Pro 구독
- **온보딩**: 수입/저축 목표 입력 후 AI 예산 자동 생성

## 카테고리

| 지출 | 수입 |
|---|---|
| 식비, 술, 교통, 카페, 쇼핑, 기타 | 알바, 용돈, 기타수입 |

## 스크린샷

<img src="flutter_01.png" width="300"> <img src="flutter_02.png" width="300">

## 기술 스택

| 레이어 | 패키지 |
|---|---|
| 라우팅 | go_router ^14.8.1 |
| 백엔드 | supabase_flutter ^2.8.4 |
| AI | Gemini API (gemini-3.5-flash) |
| 환경 변수 | flutter_dotenv ^5.2.1 |
| 달력 | table_calendar |
| 알림 | flutter_local_notifications ^18.0.1 |

## 시작하기

### 1. 의존성 설치

```bash
flutter pub get
```

### 2. 환경 변수 설정

프로젝트 루트에 `.env` 파일을 생성하고 아래 키를 입력합니다.

```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
GEMINI_API_KEY=your_gemini_api_key
```

### 3. 앱 실행

```bash
flutter run
```

## 아키텍처

- **라우팅**: `GoRouter` + `StatefulShellRoute.indexedStack` (탭 네비게이션)
- **상태 관리**: `StorageService` 직접 호출 방식 (전역 상태 관리 미사용)
- **AI 캐싱**: `SharedPreferences`에 일 1회 캐시 (홈 경고, 분석 리포트)
- **백엔드**: Supabase (PostgreSQL)

## 브랜치 전략

```
feature/* → develop → main
```

feature 브랜치는 반드시 `develop`에만 머지합니다.
