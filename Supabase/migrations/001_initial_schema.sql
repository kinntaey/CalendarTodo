-- ============================================
-- 사용자 프로필
-- ============================================

CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    timezone TEXT NOT NULL DEFAULT 'Asia/Seoul',
    apns_device_tokens TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_profiles_username ON profiles(username);

-- ============================================
-- 친구 관계
-- ============================================

CREATE TABLE friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'blocked')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(requester_id, addressee_id)
);

CREATE INDEX idx_friendships_addressee ON friendships(addressee_id, status);
CREATE INDEX idx_friendships_requester ON friendships(requester_id, status);

-- ============================================
-- 태그/카테고리
-- ============================================

CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    color TEXT NOT NULL DEFAULT '#007AFF',
    icon TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(owner_id, name)
);

-- ============================================
-- 캘린더 이벤트
-- ============================================

CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    is_all_day BOOLEAN NOT NULL DEFAULT false,

    -- 위치 (Google Maps)
    location_name TEXT,
    location_address TEXT,
    location_lat DOUBLE PRECISION,
    location_lng DOUBLE PRECISION,
    location_place_id TEXT,

    -- 반복 규칙 (JSON)
    recurrence_rule JSONB,
    recurrence_parent_id UUID REFERENCES events(id) ON DELETE CASCADE,
    recurrence_exception_dates DATE[],

    -- 알람 (분 단위 배열)
    alarms INTEGER[] DEFAULT '{}',

    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- 동기화
    sync_version BIGINT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX idx_events_owner_date ON events(owner_id, start_at, end_at);
CREATE INDEX idx_events_recurrence ON events(recurrence_parent_id);
CREATE INDEX idx_events_sync ON events(owner_id, sync_version);

-- 이벤트-태그
CREATE TABLE event_tags (
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (event_id, tag_id)
);

-- 이벤트 참석자
CREATE TABLE event_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'declined', 'maybe')),
    invited_by UUID NOT NULL REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(event_id, user_id)
);

CREATE INDEX idx_event_participants_user ON event_participants(user_id, status);

-- ============================================
-- 투두 리스트
-- ============================================

CREATE TABLE todo_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    list_type TEXT NOT NULL CHECK (list_type IN ('daily', 'weekly', 'custom')),
    week_start_date DATE,
    is_shared BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    sync_version BIGINT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX idx_todo_lists_owner ON todo_lists(owner_id, list_type);

-- 공유 투두 멤버
CREATE TABLE todo_list_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    todo_list_id UUID NOT NULL REFERENCES todo_lists(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'member')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
    invited_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(todo_list_id, user_id)
);

-- 투두 항목
CREATE TABLE todos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    todo_list_id UUID REFERENCES todo_lists(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    completed_at TIMESTAMPTZ,
    completed_by UUID REFERENCES profiles(id),

    assigned_date DATE,
    due_date DATE,
    priority INTEGER NOT NULL DEFAULT 0 CHECK (priority BETWEEN 0 AND 3),
    sort_order INTEGER NOT NULL DEFAULT 0,

    -- 친구 할당
    assigned_to UUID REFERENCES profiles(id),
    assignment_status TEXT DEFAULT 'none'
        CHECK (assignment_status IN ('none', 'pending', 'accepted', 'declined')),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    sync_version BIGINT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX idx_todos_list ON todos(todo_list_id, sort_order);
CREATE INDEX idx_todos_owner_date ON todos(owner_id, assigned_date);
CREATE INDEX idx_todos_assigned ON todos(assigned_to, assignment_status);
CREATE INDEX idx_todos_sync ON todos(owner_id, sync_version);

-- 투두-태그
CREATE TABLE todo_tags (
    todo_id UUID NOT NULL REFERENCES todos(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (todo_id, tag_id)
);

-- ============================================
-- 알림
-- ============================================

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES profiles(id),
    type TEXT NOT NULL CHECK (type IN (
        'friend_request', 'friend_accepted',
        'event_invitation', 'event_response',
        'todo_assigned', 'todo_assignment_response',
        'todo_list_invitation', 'todo_list_response',
        'todo_completed', 'event_alarm'
    )),
    reference_type TEXT,
    reference_id UUID,
    title TEXT NOT NULL,
    body TEXT,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_recipient ON notifications(recipient_id, is_read, created_at DESC);

-- ============================================
-- 동기화 커서
-- ============================================

CREATE TABLE sync_cursors (
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL,
    last_sync_version BIGINT NOT NULL DEFAULT 0,
    last_synced_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, entity_type)
);

-- ============================================
-- updated_at 자동 갱신 트리거
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_profiles_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tr_events_updated_at BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tr_todo_lists_updated_at BEFORE UPDATE ON todo_lists
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tr_todos_updated_at BEFORE UPDATE ON todos
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tr_friendships_updated_at BEFORE UPDATE ON friendships
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tr_event_participants_updated_at BEFORE UPDATE ON event_participants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- sync_version 자동 증가 트리거
-- ============================================

CREATE OR REPLACE FUNCTION increment_sync_version()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sync_version = OLD.sync_version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_events_sync_version BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE FUNCTION increment_sync_version();
CREATE TRIGGER tr_todo_lists_sync_version BEFORE UPDATE ON todo_lists
    FOR EACH ROW EXECUTE FUNCTION increment_sync_version();
CREATE TRIGGER tr_todos_sync_version BEFORE UPDATE ON todos
    FOR EACH ROW EXECUTE FUNCTION increment_sync_version();
