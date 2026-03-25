# CalendarTodo - 구현 계획

## 기술 스택

| 구분 | 선택 | 이유 |
|------|------|------|
| 프론트엔드 | SwiftUI | Apple 전용 앱, WidgetKit/APNs 네이티브 |
| 백엔드 | Supabase | PostgreSQL 관계형 DB, RLS, Realtime |
| 로컬 DB | SwiftData | 오프라인 우선, App Group 위젯 공유 |
| 인증 | Apple / Google Sign-in | Supabase Auth 연동 |
| 푸시 | APNs + Supabase Edge Functions | 서버 → APNs HTTP/2 |
| 위젯 | WidgetKit | iOS/iPadOS/macOS 네이티브 |

---

## Phase 1: 기초 ✅ 완료

- [x] Xcode 프로젝트 생성 (iOS, macOS 타겟)
- [x] CalendarTodoCore Swift Package 생성
- [x] SwiftData 모델 정의 (LocalEvent, LocalTodo, LocalTodoList, LocalTag, LocalProfile, LocalNotification, SyncCursor)
- [x] RecurrenceRule 구조체 (반복 규칙)
- [x] Supabase 초기 스키마 (001_initial_schema.sql)
- [x] RLS 정책 (002_rls_policies.sql)
- [x] SupabaseService, AuthService (Apple/Google 로그인)
- [x] ProfileSetupView (@username 설정)
- [x] App Group 설정
- [x] NetworkMonitor, KeychainHelper 유틸
- [x] WidgetKit Extension (DailyTodoWidget, UpcomingEventsWidget 스캐폴드)
- [x] Push Notification Edge Function 스캐폴드

---

## Phase 2: 캘린더 핵심 ✅ 완료

- [x] CalendarMonthView (월간 그리드, 이벤트 도트, 날짜 선택)
- [x] CalendarWeekView (주간 날짜 헤더 + 이벤트 목록)
- [x] CalendarDayView (24시간 타임라인)
- [x] CalendarContainerView (월/주/일 뷰 전환, 선택일 이벤트 목록)
- [x] EventEditView (이벤트 생성/수정 폼)
- [x] EventDetailView (이벤트 상세 + 수정/삭제)
- [x] AlarmPickerView (10분~1개월 전)
- [x] RecurrencePickerView (매일/매주/매달/매년, 평일/주말 프리셋, 요일 선택)
- [x] LocationSearchView (MapKit MKLocalSearch 기반)
- [x] EventRepository (SwiftData CRUD, 날짜 범위 쿼리)
- [x] CalendarViewModel, EventViewModel
- [x] DateHelpers 유틸 (한국어 로케일)

---

## Phase 3: 투두 핵심 (예상 2주)

- [ ] TodoRepository (SwiftData CRUD)
- [ ] DailyTodoView (일일 할 일 목록)
  - [ ] 투두 추가/수정/삭제
  - [ ] 완료 체크 토글
  - [ ] 우선순위 표시
  - [ ] 정렬 (드래그 or 우선순위)
- [ ] WeeklyTodoView (주간 할 일)
  - [ ] 이번 주 할 일 목록 → 요일별 배정
  - [ ] 드래그&드롭으로 요일 이동
  - [ ] 다음 주로 투두 이동 기능
- [ ] TodoEditView (투두 생성/수정 폼)
- [ ] DailyTodoViewModel, WeeklyTodoViewModel
- [ ] ContentView 플레이스홀더 교체

---

## Phase 4: 동기화 엔진 (예상 2-3주)

- [ ] ChangeTracker (SwiftData 변경 감지 + 큐잉)
- [ ] SyncCoordinator (Upload / Download / Merge)
  - [ ] pendingUpload → Supabase upsert
  - [ ] sync_cursors 기반 변경분 fetch
  - [ ] 로컬/서버 병합
- [ ] ConflictResolver
  - [ ] Last-Write-Wins (updated_at 기준)
  - [ ] 삭제 vs 수정 → 삭제 우선
  - [ ] 중요 충돌 → 사용자 선택 UI
- [ ] Supabase Realtime 구독 (온라인 시 실시간 반영)
- [ ] 동기화 상태 UI (동기화 중, 오프라인 배지)
- [ ] NetworkMonitor 연동 (네트워크 복구 시 자동 동기화)

---

## Phase 5: 소셜 기능 (예상 2-3주)

- [ ] 친구 검색 (@username)
- [ ] 친구 요청 보내기/수락/거절
- [ ] 친구 목록 관리
- [ ] 이벤트에 친구 초대
  - [ ] 초대 보내기 → 푸시 알림
  - [ ] 수락 시 친구 캘린더에 이벤트 추가
- [ ] 친구에게 투두 할당
  - [ ] 할당 보내기 → 알림 + 수락 플로우
  - [ ] 수락 시 친구 투두 리스트에 추가
- [ ] 공유 투두 리스트
  - [ ] 생성 + 멤버 초대
  - [ ] 협업 추가/삭제/완료
  - [ ] Realtime으로 실시간 반영
- [ ] APNs 등록 + 디바이스 토큰 관리
- [ ] Edge Function: 푸시 발송 구현
- [ ] 인앱 알림 센터 UI (NotificationsView)

---

## Phase 6: 위젯 (예상 1-2주)

- [ ] 오늘 할 일 위젯 (Small, Medium)
  - [ ] TimelineProvider에서 SwiftData 읽기
  - [ ] Interactive Widget: 투두 완료 토글
- [ ] 다가오는 일정 위젯 (Small, Medium, Large)
- [ ] 주간 개요 위젯 (Medium, Large)
- [ ] macOS 메뉴바 위젯 (MenuBarExtra)
- [ ] 앱 데이터 변경 시 WidgetCenter.reloadAllTimelines()

---

## Phase 7: 마무리 및 최적화 (예상 1-2주)

- [ ] 서버 측 반복 이벤트 알람 스케줄링 (pg_cron)
- [ ] 대량 데이터 성능 최적화 (페이지네이션)
- [ ] 에러 핸들링 통합
- [ ] 접근성 (VoiceOver, Dynamic Type)
- [ ] 다크모드 대응
- [ ] 앱 아이콘 디자인
- [ ] 온보딩 화면
- [ ] 설정 화면 (알림 설정, 계정 관리, 로그아웃)

---

## 데이터베이스 스키마 요약

```
profiles ──1:N── events
profiles ──1:N── todo_lists
profiles ──1:N── todos
profiles ──M:N── profiles (friendships)
profiles ──1:N── tags

events ──M:N── profiles (event_participants)
events ──M:N── tags (event_tags)
events ──1:N── events (recurrence parent → instances)

todo_lists ──1:N── todos
todo_lists ──M:N── profiles (todo_list_members)
todos ──M:N── tags (todo_tags)
todos ──N:1── profiles (assigned_to)

profiles ──1:N── notifications
```

## 오프라인 동기화 전략

- **로컬**: SwiftData가 Single Source of Truth
- **동기화**: sync_version 기반 변경분만 전송
- **충돌 해결**: Last-Write-Wins + 사용자 선택 (중요 충돌)
- **실시간**: Supabase Realtime 구독 (온라인 시)
- **알람**: 가까운 64개는 UNNotification, 먼 알람은 서버 APNs

## 프로젝트 구조

```
CalendarTodo/
├── CalendarTodoApp/          # SwiftUI 앱 (iOS/macOS)
│   ├── App/                  # 앱 진입점, RootView, ContentView
│   ├── Features/
│   │   ├── Auth/             # 로그인, 프로필 설정
│   │   ├── Calendar/         # 캘린더 뷰, 이벤트 CRUD
│   │   ├── Todo/             # 일일/주간 투두
│   │   ├── Social/           # 친구, 알림
│   │   └── Settings/         # 설정
│   ├── Shared/               # 공용 컴포넌트
│   └── Platform/             # 플랫폼별 분기
├── CalendarTodoCore/         # Swift Package (공유 로직)
│   └── Sources/
│       ├── Models/           # SwiftData 모델
│       ├── Repositories/     # 데이터 접근 계층
│       ├── Services/         # Supabase, Auth, 위치 등
│       ├── Sync/             # 동기화 엔진
│       └── Utils/            # 유틸리티
├── CalendarTodoWidgets/      # WidgetKit Extension
├── Supabase/
│   ├── migrations/           # SQL 스키마
│   └── functions/            # Edge Functions
└── project.yml               # XcodeGen 설정
```
