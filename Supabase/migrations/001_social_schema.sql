-- ============================================
-- CalendarTodo Social Schema
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. Profiles
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    timezone TEXT DEFAULT 'Asia/Seoul',
    apns_device_tokens TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_profiles_username_trgm ON profiles USING gin (username gin_trgm_ops);

-- 2. Friendships
CREATE TABLE IF NOT EXISTS friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(requester_id, addressee_id),
    CHECK (requester_id != addressee_id)
);

-- 3. Events
CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    is_all_day BOOLEAN DEFAULT false,
    location_name TEXT,
    location_address TEXT,
    location_lat DOUBLE PRECISION,
    location_lng DOUBLE PRECISION,
    location_place_id TEXT,
    recurrence_rule JSONB,
    recurrence_exception_dates TIMESTAMPTZ[],
    alarms INTEGER[] DEFAULT '{}',
    color TEXT DEFAULT '#007AFF',
    status TEXT DEFAULT 'active',
    is_deleted BOOLEAN DEFAULT false,
    sync_version BIGINT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Event Participants
CREATE TABLE IF NOT EXISTS event_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending',
    invited_by UUID NOT NULL REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(event_id, user_id)
);

-- 5. Todo Lists
CREATE TABLE IF NOT EXISTS todo_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    list_type TEXT DEFAULT 'custom',
    week_start_date DATE,
    is_shared BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,
    sync_version BIGINT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 6. Todo List Members
CREATE TABLE IF NOT EXISTS todo_list_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    todo_list_id UUID NOT NULL REFERENCES todo_lists(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member',
    status TEXT NOT NULL DEFAULT 'pending',
    invited_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(todo_list_id, user_id)
);

-- 7. Todos
CREATE TABLE IF NOT EXISTS todos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    todo_list_id UUID REFERENCES todo_lists(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    is_completed BOOLEAN DEFAULT false,
    completed_at TIMESTAMPTZ,
    completed_by UUID REFERENCES profiles(id),
    assigned_date DATE,
    due_date TIMESTAMPTZ,
    priority INTEGER DEFAULT 0,
    sort_order INTEGER DEFAULT 0,
    assigned_to UUID REFERENCES profiles(id),
    assignment_status TEXT DEFAULT 'none',
    recurrence_rule JSONB,
    is_deleted BOOLEAN DEFAULT false,
    sync_version BIGINT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 8. Notifications
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES profiles(id),
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT,
    reference_type TEXT,
    reference_id UUID,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- RLS Policies (all tables exist now)
-- ============================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Secure function to read device tokens (only service_role or self)
CREATE OR REPLACE FUNCTION get_device_tokens(p_user_id UUID)
RETURNS TEXT[] AS $$
BEGIN
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;
    RETURN (SELECT apns_device_tokens FROM profiles WHERE id = p_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
CREATE POLICY "friendships_select" ON friendships FOR SELECT
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
CREATE POLICY "friendships_insert" ON friendships FOR INSERT
    WITH CHECK (auth.uid() = requester_id);
CREATE POLICY "friendships_update" ON friendships FOR UPDATE
    USING (auth.uid() = addressee_id);
CREATE POLICY "friendships_delete" ON friendships FOR DELETE
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

ALTER TABLE events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "events_select" ON events FOR SELECT
    USING (
        auth.uid() = owner_id
        OR EXISTS (
            SELECT 1 FROM event_participants
            WHERE event_id = events.id AND user_id = auth.uid() AND status = 'accepted'
        )
    );
CREATE POLICY "events_insert" ON events FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "events_update" ON events FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "events_delete" ON events FOR DELETE USING (auth.uid() = owner_id);

ALTER TABLE event_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ep_select" ON event_participants FOR SELECT
    USING (auth.uid() = user_id OR auth.uid() = invited_by);
CREATE POLICY "ep_insert" ON event_participants FOR INSERT
    WITH CHECK (auth.uid() = invited_by);
CREATE POLICY "ep_update" ON event_participants FOR UPDATE
    USING (auth.uid() = user_id);
CREATE POLICY "ep_delete" ON event_participants FOR DELETE
    USING (auth.uid() = invited_by);

ALTER TABLE todo_lists ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tl_select" ON todo_lists FOR SELECT
    USING (
        auth.uid() = owner_id
        OR EXISTS (
            SELECT 1 FROM todo_list_members
            WHERE todo_list_id = todo_lists.id AND user_id = auth.uid() AND status = 'accepted'
        )
        OR (
            is_shared = true
            AND EXISTS (
                SELECT 1 FROM friendships
                WHERE status = 'accepted'
                AND (
                    (requester_id = auth.uid() AND addressee_id = todo_lists.owner_id)
                    OR (addressee_id = auth.uid() AND requester_id = todo_lists.owner_id)
                )
            )
        )
    );
CREATE POLICY "tl_insert" ON todo_lists FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "tl_update" ON todo_lists FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "tl_delete" ON todo_lists FOR DELETE USING (auth.uid() = owner_id);

ALTER TABLE todo_list_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tlm_select" ON todo_list_members FOR SELECT
    USING (auth.uid() = user_id OR auth.uid() = invited_by);
CREATE POLICY "tlm_insert" ON todo_list_members FOR INSERT
    WITH CHECK (auth.uid() = invited_by);
CREATE POLICY "tlm_update" ON todo_list_members FOR UPDATE
    USING (auth.uid() = user_id);
CREATE POLICY "tlm_delete" ON todo_list_members FOR DELETE
    USING (auth.uid() = invited_by);

ALTER TABLE todos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "todos_select" ON todos FOR SELECT
    USING (
        auth.uid() = owner_id
        OR auth.uid() = assigned_to
        OR EXISTS (
            SELECT 1 FROM todo_list_members
            WHERE todo_list_id = todos.todo_list_id AND user_id = auth.uid() AND status = 'accepted'
        )
        OR EXISTS (
            SELECT 1 FROM todo_lists tl
            WHERE tl.id = todos.todo_list_id AND tl.is_shared = true
            AND EXISTS (
                SELECT 1 FROM friendships
                WHERE status = 'accepted'
                AND (
                    (requester_id = auth.uid() AND addressee_id = tl.owner_id)
                    OR (addressee_id = auth.uid() AND requester_id = tl.owner_id)
                )
            )
        )
    );
CREATE POLICY "todos_insert" ON todos FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "todos_update" ON todos FOR UPDATE
    USING (
        auth.uid() = owner_id
        OR auth.uid() = assigned_to
        OR EXISTS (
            SELECT 1 FROM todo_list_members
            WHERE todo_list_id = todos.todo_list_id AND user_id = auth.uid() AND status = 'accepted'
        )
    );
CREATE POLICY "todos_delete" ON todos FOR DELETE USING (auth.uid() = owner_id);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "notif_select" ON notifications FOR SELECT
    USING (auth.uid() = recipient_id);
CREATE POLICY "notif_insert" ON notifications FOR INSERT
    WITH CHECK (auth.uid() = sender_id OR sender_id IS NULL);
CREATE POLICY "notif_update" ON notifications FOR UPDATE
    USING (auth.uid() = recipient_id);
CREATE POLICY "notif_delete" ON notifications FOR DELETE
    USING (auth.uid() = recipient_id);

-- ============================================
-- Functions
-- ============================================

-- Prevent reverse friend request
CREATE OR REPLACE FUNCTION check_friendship_no_reverse()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM friendships
        WHERE requester_id = NEW.addressee_id
          AND addressee_id = NEW.requester_id
    ) THEN
        RAISE EXCEPTION 'Reverse friendship already exists';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_friendships_no_reverse
    BEFORE INSERT ON friendships
    FOR EACH ROW EXECUTE FUNCTION check_friendship_no_reverse();

-- Clone event for invitation accept (with authorization check)
CREATE OR REPLACE FUNCTION clone_event_for_participant(p_event_id UUID, p_user_id UUID)
RETURNS UUID AS $$
DECLARE
    v_new_id UUID := gen_random_uuid();
    v_src events%ROWTYPE;
BEGIN
    -- Authorization: caller must be the target user
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'Unauthorized: can only clone for yourself';
    END IF;

    -- Verify user is a pending participant
    IF NOT EXISTS (
        SELECT 1 FROM event_participants
        WHERE event_id = p_event_id AND user_id = p_user_id AND status IN ('pending', 'accepted')
    ) THEN
        RAISE EXCEPTION 'Not a participant of this event';
    END IF;

    SELECT * INTO v_src FROM events WHERE id = p_event_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Event not found'; END IF;

    INSERT INTO events (id, owner_id, title, description, start_at, end_at, is_all_day,
        location_name, location_address, location_lat, location_lng, location_place_id,
        recurrence_rule, alarms, color, status)
    VALUES (v_new_id, p_user_id, v_src.title, v_src.description,
        v_src.start_at, v_src.end_at, v_src.is_all_day,
        v_src.location_name, v_src.location_address, v_src.location_lat, v_src.location_lng, v_src.location_place_id,
        v_src.recurrence_rule, v_src.alarms, v_src.color, 'active');

    RETURN v_new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Clone todo for assignment accept (with authorization check)
CREATE OR REPLACE FUNCTION clone_todo_for_assignee(p_todo_id UUID, p_user_id UUID)
RETURNS UUID AS $$
DECLARE
    v_new_id UUID := gen_random_uuid();
    v_src todos%ROWTYPE;
BEGIN
    -- Authorization: caller must be the target user
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'Unauthorized: can only clone for yourself';
    END IF;

    -- Verify user is the assigned recipient
    IF NOT EXISTS (
        SELECT 1 FROM todos
        WHERE id = p_todo_id AND assigned_to = p_user_id AND assignment_status = 'pending'
    ) THEN
        RAISE EXCEPTION 'Not assigned to this todo';
    END IF;

    SELECT * INTO v_src FROM todos WHERE id = p_todo_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Todo not found'; END IF;

    INSERT INTO todos (id, owner_id, title, description, assigned_date, due_date, priority, sort_order)
    VALUES (v_new_id, p_user_id, v_src.title, v_src.description,
        v_src.assigned_date, v_src.due_date, v_src.priority, 0);

    RETURN v_new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Username format constraint
ALTER TABLE profiles ADD CONSTRAINT IF NOT EXISTS check_username_format
    CHECK (username ~ '^[a-z0-9_]{3,20}$');

-- ============================================
-- Realtime
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE friendships;
ALTER PUBLICATION supabase_realtime ADD TABLE event_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE todos;
ALTER PUBLICATION supabase_realtime ADD TABLE todo_list_members;
