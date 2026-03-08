-- ============================================
-- RLS 활성화
-- ============================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE todo_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE todo_list_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;
ALTER TABLE todo_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_cursors ENABLE ROW LEVEL SECURITY;

-- ============================================
-- Profiles
-- ============================================

-- 누구나 프로필 조회 가능 (친구 검색용)
CREATE POLICY profiles_select ON profiles
    FOR SELECT USING (true);

-- 본인 프로필만 수정
CREATE POLICY profiles_update ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- 본인 프로필 생성
CREATE POLICY profiles_insert ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- ============================================
-- Friendships
-- ============================================

-- 본인이 관련된 친구 관계만 조회
CREATE POLICY friendships_select ON friendships
    FOR SELECT USING (
        auth.uid() = requester_id OR auth.uid() = addressee_id
    );

-- 친구 요청 생성
CREATE POLICY friendships_insert ON friendships
    FOR INSERT WITH CHECK (auth.uid() = requester_id);

-- 본인이 관련된 친구 관계만 수정 (수락/거절)
CREATE POLICY friendships_update ON friendships
    FOR UPDATE USING (
        auth.uid() = requester_id OR auth.uid() = addressee_id
    );

-- 본인이 관련된 친구 관계만 삭제
CREATE POLICY friendships_delete ON friendships
    FOR DELETE USING (
        auth.uid() = requester_id OR auth.uid() = addressee_id
    );

-- ============================================
-- Tags
-- ============================================

CREATE POLICY tags_select ON tags
    FOR SELECT USING (auth.uid() = owner_id);

CREATE POLICY tags_insert ON tags
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY tags_update ON tags
    FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY tags_delete ON tags
    FOR DELETE USING (auth.uid() = owner_id);

-- ============================================
-- Events
-- ============================================

-- 본인 이벤트 또는 참석자로 초대된 이벤트 조회
CREATE POLICY events_select ON events
    FOR SELECT USING (
        auth.uid() = owner_id
        OR id IN (
            SELECT event_id FROM event_participants
            WHERE user_id = auth.uid() AND status = 'accepted'
        )
    );

CREATE POLICY events_insert ON events
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY events_update ON events
    FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY events_delete ON events
    FOR DELETE USING (auth.uid() = owner_id);

-- ============================================
-- Event Tags
-- ============================================

CREATE POLICY event_tags_select ON event_tags
    FOR SELECT USING (
        event_id IN (SELECT id FROM events WHERE owner_id = auth.uid())
    );

CREATE POLICY event_tags_insert ON event_tags
    FOR INSERT WITH CHECK (
        event_id IN (SELECT id FROM events WHERE owner_id = auth.uid())
    );

CREATE POLICY event_tags_delete ON event_tags
    FOR DELETE USING (
        event_id IN (SELECT id FROM events WHERE owner_id = auth.uid())
    );

-- ============================================
-- Event Participants
-- ============================================

-- 본인이 초대한 or 초대받은 참석 정보 조회
CREATE POLICY event_participants_select ON event_participants
    FOR SELECT USING (
        auth.uid() = user_id
        OR auth.uid() = invited_by
        OR event_id IN (SELECT id FROM events WHERE owner_id = auth.uid())
    );

-- 이벤트 소유자만 참석자 추가 가능
CREATE POLICY event_participants_insert ON event_participants
    FOR INSERT WITH CHECK (
        event_id IN (SELECT id FROM events WHERE owner_id = auth.uid())
    );

-- 초대받은 본인만 상태 변경 가능 (수락/거절)
CREATE POLICY event_participants_update ON event_participants
    FOR UPDATE USING (auth.uid() = user_id);

-- 이벤트 소유자만 참석자 삭제
CREATE POLICY event_participants_delete ON event_participants
    FOR DELETE USING (
        event_id IN (SELECT id FROM events WHERE owner_id = auth.uid())
    );

-- ============================================
-- Todo Lists
-- ============================================

-- 본인 리스트 또는 멤버인 공유 리스트 조회
CREATE POLICY todo_lists_select ON todo_lists
    FOR SELECT USING (
        auth.uid() = owner_id
        OR (is_shared = true AND id IN (
            SELECT todo_list_id FROM todo_list_members
            WHERE user_id = auth.uid() AND status = 'accepted'
        ))
    );

CREATE POLICY todo_lists_insert ON todo_lists
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY todo_lists_update ON todo_lists
    FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY todo_lists_delete ON todo_lists
    FOR DELETE USING (auth.uid() = owner_id);

-- ============================================
-- Todo List Members
-- ============================================

CREATE POLICY todo_list_members_select ON todo_list_members
    FOR SELECT USING (
        auth.uid() = user_id
        OR todo_list_id IN (SELECT id FROM todo_lists WHERE owner_id = auth.uid())
    );

CREATE POLICY todo_list_members_insert ON todo_list_members
    FOR INSERT WITH CHECK (
        todo_list_id IN (SELECT id FROM todo_lists WHERE owner_id = auth.uid())
    );

CREATE POLICY todo_list_members_update ON todo_list_members
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY todo_list_members_delete ON todo_list_members
    FOR DELETE USING (
        todo_list_id IN (SELECT id FROM todo_lists WHERE owner_id = auth.uid())
    );

-- ============================================
-- Todos
-- ============================================

-- 본인 투두, 할당받은 투두, 공유 리스트의 투두 조회
CREATE POLICY todos_select ON todos
    FOR SELECT USING (
        auth.uid() = owner_id
        OR auth.uid() = assigned_to
        OR todo_list_id IN (
            SELECT todo_list_id FROM todo_list_members
            WHERE user_id = auth.uid() AND status = 'accepted'
        )
    );

CREATE POLICY todos_insert ON todos
    FOR INSERT WITH CHECK (
        auth.uid() = owner_id
        OR todo_list_id IN (
            SELECT todo_list_id FROM todo_list_members
            WHERE user_id = auth.uid() AND status = 'accepted'
        )
    );

CREATE POLICY todos_update ON todos
    FOR UPDATE USING (
        auth.uid() = owner_id
        OR auth.uid() = assigned_to
        OR todo_list_id IN (
            SELECT todo_list_id FROM todo_list_members
            WHERE user_id = auth.uid() AND status = 'accepted'
        )
    );

CREATE POLICY todos_delete ON todos
    FOR DELETE USING (auth.uid() = owner_id);

-- ============================================
-- Todo Tags
-- ============================================

CREATE POLICY todo_tags_select ON todo_tags
    FOR SELECT USING (
        todo_id IN (SELECT id FROM todos WHERE owner_id = auth.uid())
    );

CREATE POLICY todo_tags_insert ON todo_tags
    FOR INSERT WITH CHECK (
        todo_id IN (SELECT id FROM todos WHERE owner_id = auth.uid())
    );

CREATE POLICY todo_tags_delete ON todo_tags
    FOR DELETE USING (
        todo_id IN (SELECT id FROM todos WHERE owner_id = auth.uid())
    );

-- ============================================
-- Notifications
-- ============================================

CREATE POLICY notifications_select ON notifications
    FOR SELECT USING (auth.uid() = recipient_id);

CREATE POLICY notifications_insert ON notifications
    FOR INSERT WITH CHECK (auth.uid() = sender_id OR sender_id IS NULL);

CREATE POLICY notifications_update ON notifications
    FOR UPDATE USING (auth.uid() = recipient_id);

-- ============================================
-- Sync Cursors
-- ============================================

CREATE POLICY sync_cursors_select ON sync_cursors
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY sync_cursors_upsert ON sync_cursors
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY sync_cursors_update ON sync_cursors
    FOR UPDATE USING (auth.uid() = user_id);
