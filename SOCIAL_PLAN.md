# Social Feature Implementation Plan

## Overview
CalendarTodo 앱에 친구/소셜 기능을 추가하기 위한 구현 계획서.
백엔드: Supabase (PostgreSQL + Realtime + Edge Functions + APNs)

---

## Supabase PostgreSQL Schema

### profiles (기존 확장)
```sql
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    username TEXT UNIQUE NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    apns_device_tokens TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_profiles_username_trgm ON profiles USING gin (username gin_trgm_ops);
```

### friendships
```sql
CREATE TABLE friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES profiles(id),
    addressee_id UUID NOT NULL REFERENCES profiles(id),
    status TEXT NOT NULL DEFAULT 'pending', -- pending, accepted, blocked
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(requester_id, addressee_id)
);
```

### events (기존 확장)
```sql
-- 기존 events 테이블에 추가 없음. 초대 수락 시 clone_event_for_participant() 함수로 복제.
```

### event_participants
```sql
CREATE TABLE event_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id),
    status TEXT NOT NULL DEFAULT 'pending', -- pending, accepted, declined, maybe
    invited_by UUID NOT NULL REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(event_id, user_id)
);
```

### todo_lists (기존 확장)
```sql
-- is_shared 필드 추가
ALTER TABLE todo_lists ADD COLUMN is_shared BOOLEAN DEFAULT false;
```

### todo_list_members
```sql
CREATE TABLE todo_list_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    todo_list_id UUID NOT NULL REFERENCES todo_lists(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id),
    role TEXT NOT NULL DEFAULT 'member', -- owner, member
    status TEXT NOT NULL DEFAULT 'pending', -- pending, accepted, declined
    invited_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(todo_list_id, user_id)
);
```

### notifications
```sql
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES profiles(id),
    sender_id UUID REFERENCES profiles(id),
    type TEXT NOT NULL, -- friend_request, friend_accepted, event_invitation, event_response, todo_assigned, todo_assignment_response, todo_list_invitation
    title TEXT NOT NULL,
    body TEXT,
    reference_type TEXT, -- friendship, event_participant, todo, todo_list_member
    reference_id UUID,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);
```

### DB Functions
```sql
-- 이벤트 복제 (초대 수락 시)
CREATE OR REPLACE FUNCTION clone_event_for_participant(p_event_id UUID, p_user_id UUID) RETURNS UUID;
-- 할 일 복제 (배정 수락 시)
CREATE OR REPLACE FUNCTION clone_todo_for_assignee(p_todo_id UUID, p_user_id UUID) RETURNS UUID;
-- 중복 친구 요청 방지 트리거
CREATE TRIGGER tr_friendships_no_reverse BEFORE INSERT ON friendships;
```

### Realtime 활성화
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE todos;
ALTER PUBLICATION supabase_realtime ADD TABLE todo_list_members;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE event_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE friendships;
```

### RLS 정책 요약
| 테이블 | SELECT | INSERT | UPDATE | DELETE |
|--------|--------|--------|--------|--------|
| profiles | 누구나 | 본인만 | 본인만 | - |
| friendships | 요청자/수신자 | 요청자 | 수신자 (수락/거절) | 요청자/수신자 |
| events | 소유자/참가자 | 소유자 | 소유자 | 소유자 |
| event_participants | 소유자/초대자/초대받은자 | 이벤트 소유자 | 초대받은자 (응답) | 이벤트 소유자 |
| todo_lists | 소유자/멤버 | 소유자 | 소유자 | 소유자 |
| todo_list_members | 멤버/리스트 소유자 | 리스트 소유자 | 멤버 (응답) | 리스트 소유자 |
| todos | 소유자/담당자/공유멤버 | 소유자/공유멤버 | 소유자/담당자/공유멤버 | 소유자 |
| notifications | 수신자만 | 발신자/서버 | 수신자 (읽음처리) | - |

---

## Data Flow

### 친구 요청
```
검색: profiles WHERE username ILIKE '%query%'
요청: INSERT friendships (status='pending') → INSERT notification → APNs 푸시
수락: UPDATE friendships SET status='accepted' → 양쪽 친구 목록에 표시
거절: DELETE friendships
```

### 일정 초대
```
초대: INSERT event_participants (status='pending') → INSERT notification → APNs 푸시
수락: UPDATE event_participants SET status='accepted'
      → clone_event_for_participant() → 초대받은 사람 캘린더에 복제 (알람/반복 포함)
거절: UPDATE event_participants SET status='declined'
```

### 할 일 배정
```
배정: UPDATE todo SET assigned_to=friend, assignment_status='pending' → INSERT notification
수락: clone_todo_for_assignee() → 친구 할 일 목록에 추가
거절: UPDATE todo SET assignment_status='declined'
```

### 공유 할 일 목록
```
생성: INSERT todo_list (is_shared=true) → INSERT todo_list_members (각 친구)
초대 수락: UPDATE todo_list_members SET status='accepted' → Realtime 구독 시작
편집: 모든 accepted 멤버가 INSERT/UPDATE/DELETE todos 가능
실시간: Supabase Realtime으로 변경사항 즉시 전파
```

---

## Implementation Phases

### Phase 5A: 친구 시스템
**새 파일:**
- `CalendarTodoCore/Sources/Models/LocalFriendship.swift`
- `CalendarTodoCore/Sources/Models/LocalNotification.swift`
- `CalendarTodoCore/Sources/Services/SupabaseService.swift`
- `CalendarTodoCore/Sources/Services/FriendshipService.swift`
- `CalendarTodoCore/Sources/Repositories/FriendshipRepository.swift`
- `CalendarTodoApp/Features/Social/Views/SocialView.swift`
- `CalendarTodoApp/Features/Social/Views/FriendSearchView.swift`
- `CalendarTodoApp/Features/Social/Views/FriendListView.swift`
- `CalendarTodoApp/Features/Social/Views/FriendRequestsView.swift`
- `CalendarTodoApp/Features/Social/ViewModels/SocialViewModel.swift`

**수정 파일:**
- `CalendarTodoApp/App/CalendarTodoApp.swift` - SwiftData 모델 추가
- `CalendarTodoApp/App/ContentView.swift` - 소셜 탭 교체
- `CalendarTodoApp/App/L10n.swift` - 소셜 관련 문자열 추가

### Phase 5B: 알림 시스템
**새 파일:**
- `Supabase/functions/send-push-notification/index.ts`
- `CalendarTodoCore/Sources/Services/PushNotificationService.swift`
- `CalendarTodoCore/Sources/Services/NotificationSyncService.swift`
- `CalendarTodoApp/Features/Social/Views/NotificationCenterView.swift`
- `CalendarTodoApp/Features/Social/ViewModels/NotificationViewModel.swift`

**수정 파일:**
- `CalendarTodoApp/App/CalendarTodoApp.swift` - UIApplicationDelegateAdaptor 추가
- `CalendarTodoApp/App/ContentView.swift` - 알림 뱃지 추가

### Phase 5C: 일정 초대
**새 파일:**
- `CalendarTodoCore/Sources/Models/LocalEventParticipant.swift`
- `CalendarTodoCore/Sources/Services/EventParticipantService.swift`
- `CalendarTodoApp/Features/Social/Views/FriendPickerSheet.swift`

**수정 파일:**
- `CalendarTodoApp/Features/Calendar/Views/EventEditView.swift` - 친구 초대 섹션
- `CalendarTodoApp/Features/Calendar/Views/EventDetailView.swift` - 참가자 표시
- `CalendarTodoApp/Features/Calendar/ViewModels/EventViewModel.swift` - 초대 로직

### Phase 5D: 할 일 공유
**새 파일:**
- `CalendarTodoCore/Sources/Models/LocalTodoListMember.swift`
- `CalendarTodoCore/Sources/Services/TodoSharingService.swift`
- `CalendarTodoCore/Sources/Services/RealtimeService.swift`
- `CalendarTodoApp/Features/Social/Views/SharedTodoListsView.swift`
- `CalendarTodoApp/Features/Social/Views/SharedTodoListDetailView.swift`
- `CalendarTodoApp/Features/Social/Views/CreateSharedListView.swift`
- `CalendarTodoApp/Features/Social/ViewModels/SharedTodoListViewModel.swift`

**수정 파일:**
- `CalendarTodoApp/Features/Todo/Views/TodoEditView.swift` - 친구 배정 기능

### Phase 5E: 오프라인 동기화
**새 파일:**
- `CalendarTodoCore/Sources/Sync/SocialSyncService.swift`
- `CalendarTodoCore/Sources/Sync/OfflineActionQueue.swift`

---

## Tech Stack
- **Backend**: Supabase (PostgreSQL + Auth + Realtime + Edge Functions)
- **Push**: Supabase Edge Functions → APNs HTTP/2
- **Local DB**: SwiftData (오프라인 캐시)
- **Swift SDK**: `supabase-swift`
- **Realtime**: Supabase Realtime (공유 할 일 목록 실시간 동기화)
