-- =========================================================
-- 002_registrations.sql — Event Registration System
-- Run in Supabase SQL Editor after 001_predictions_schema.sql
-- =========================================================

-- TABLES

CREATE TABLE IF NOT EXISTS registration_events (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL,
  event_date   date,
  event_type   text NOT NULL DEFAULT 'social'
               CHECK (event_type IN ('social','open','seniors','corporate','clinic','other')),
  description  text,
  venue        text,
  capacity     integer,
  is_open      boolean NOT NULL DEFAULT true,
  closes_at    timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS registrations (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id     uuid NOT NULL REFERENCES registration_events(id) ON DELETE CASCADE,
  name         text NOT NULL,
  phone        text NOT NULL,
  email        text,
  notes        text,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (event_id, phone)
);

-- RLS

ALTER TABLE registration_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE registrations       ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_read_reg_events"   ON registration_events FOR SELECT TO anon USING (true);
CREATE POLICY "anon_read_registrations" ON registrations       FOR SELECT TO anon USING (true);

-- PUBLIC: all open events with entry counts

CREATE OR REPLACE FUNCTION get_open_registration_events()
RETURNS TABLE(
  id uuid, name text, event_date date, event_type text,
  description text, venue text, capacity integer,
  closes_at timestamptz, entry_count bigint
) LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT e.id, e.name, e.event_date, e.event_type, e.description,
         e.venue, e.capacity, e.closes_at, COUNT(r.id) AS entry_count
  FROM   registration_events e
  LEFT JOIN registrations r ON r.event_id = e.id
  WHERE  e.is_open = true AND (e.closes_at IS NULL OR e.closes_at > now())
  GROUP  BY e.id
  ORDER  BY COALESCE(e.event_date::timestamptz, e.created_at) ASC;
$$;

-- PUBLIC: single event details (works even if closed)

CREATE OR REPLACE FUNCTION get_event_details(p_event_id uuid)
RETURNS TABLE(
  id uuid, name text, event_date date, event_type text,
  description text, venue text, capacity integer,
  is_open boolean, closes_at timestamptz, entry_count bigint
) LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT e.id, e.name, e.event_date, e.event_type, e.description,
         e.venue, e.capacity, e.is_open, e.closes_at, COUNT(r.id) AS entry_count
  FROM   registration_events e
  LEFT JOIN registrations r ON r.event_id = e.id
  WHERE  e.id = p_event_id
  GROUP  BY e.id;
$$;

-- PUBLIC: names list for an event (no phone/email)

CREATE OR REPLACE FUNCTION get_event_registrations(p_event_id uuid)
RETURNS TABLE(id uuid, name text, submitted_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT id, name, submitted_at
  FROM   registrations WHERE event_id = p_event_id
  ORDER  BY submitted_at ASC;
$$;

-- PUBLIC: submit a registration

CREATE OR REPLACE FUNCTION submit_registration(
  p_event_id uuid,
  p_name     text,
  p_phone    text,
  p_email    text DEFAULT NULL,
  p_notes    text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_event  registration_events;
  v_count  bigint;
BEGIN
  SELECT * INTO v_event FROM registration_events WHERE id = p_event_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Event not found.');
  END IF;
  IF NOT v_event.is_open OR (v_event.closes_at IS NOT NULL AND v_event.closes_at <= now()) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Registrations are closed.');
  END IF;
  IF v_event.capacity IS NOT NULL THEN
    SELECT COUNT(*) INTO v_count FROM registrations WHERE event_id = p_event_id;
    IF v_count >= v_event.capacity THEN
      RETURN jsonb_build_object('success', false, 'message', 'Sorry, this event is full.');
    END IF;
  END IF;
  IF trim(coalesce(p_name,'')) = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Please enter your name.');
  END IF;
  IF trim(coalesce(p_phone,'')) = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Please enter your WhatsApp number.');
  END IF;
  BEGIN
    INSERT INTO registrations(event_id, name, phone, email, notes)
    VALUES (p_event_id, trim(p_name), trim(p_phone),
            nullif(trim(coalesce(p_email,'')), ''),
            nullif(trim(coalesce(p_notes,'')), ''));
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'message', 'This number is already registered for this event.');
  END;
  RETURN jsonb_build_object('success', true, 'message', 'You''re in!');
END;
$$;

-- ADMIN FUNCTIONS

CREATE OR REPLACE FUNCTION admin_get_reg_events(p_session_token text)
RETURNS TABLE(
  id uuid, name text, event_date date, event_type text,
  description text, venue text, capacity integer,
  is_open boolean, closes_at timestamptz, created_at timestamptz, entry_count bigint
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM _assert_admin(p_session_token);
  RETURN QUERY
    SELECT e.id, e.name, e.event_date, e.event_type, e.description,
           e.venue, e.capacity, e.is_open, e.closes_at, e.created_at,
           COUNT(r.id)::bigint
    FROM   registration_events e
    LEFT JOIN registrations r ON r.event_id = e.id
    GROUP  BY e.id ORDER BY e.created_at DESC;
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION '%', SQLERRM;
END;
$$;

CREATE OR REPLACE FUNCTION admin_get_reg_entries(p_session_token text, p_event_id uuid)
RETURNS TABLE(id uuid, name text, phone text, email text, notes text, submitted_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM _assert_admin(p_session_token);
  RETURN QUERY
    SELECT r.id, r.name, r.phone, r.email, r.notes, r.submitted_at
    FROM   registrations r WHERE r.event_id = p_event_id
    ORDER  BY r.submitted_at ASC;
EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION '%', SQLERRM;
END;
$$;

CREATE OR REPLACE FUNCTION admin_create_reg_event(
  p_session_token text, p_name text,
  p_event_date date DEFAULT NULL, p_event_type text DEFAULT 'social',
  p_description text DEFAULT NULL, p_venue text DEFAULT NULL,
  p_capacity integer DEFAULT NULL, p_closes_at timestamptz DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  PERFORM _assert_admin(p_session_token);
  INSERT INTO registration_events(name, event_date, event_type, description, venue, capacity, closes_at)
  VALUES (trim(p_name), p_event_date, p_event_type, p_description, p_venue, p_capacity, p_closes_at)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION admin_update_reg_event(
  p_session_token text, p_id uuid, p_name text,
  p_event_date date DEFAULT NULL, p_event_type text DEFAULT 'social',
  p_description text DEFAULT NULL, p_venue text DEFAULT NULL,
  p_capacity integer DEFAULT NULL, p_is_open boolean DEFAULT true,
  p_closes_at timestamptz DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM _assert_admin(p_session_token);
  UPDATE registration_events
  SET    name=trim(p_name), event_date=p_event_date, event_type=p_event_type,
         description=p_description, venue=p_venue, capacity=p_capacity,
         is_open=p_is_open, closes_at=p_closes_at
  WHERE  id = p_id;
  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION admin_delete_reg_event(p_session_token text, p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM _assert_admin(p_session_token);
  DELETE FROM registration_events WHERE id = p_id;
  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION admin_delete_reg_entry(p_session_token text, p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM _assert_admin(p_session_token);
  DELETE FROM registrations WHERE id = p_id;
  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- GRANTS

GRANT EXECUTE ON FUNCTION get_open_registration_events()                                              TO anon;
GRANT EXECUTE ON FUNCTION get_event_details(uuid)                                                     TO anon;
GRANT EXECUTE ON FUNCTION get_event_registrations(uuid)                                               TO anon;
GRANT EXECUTE ON FUNCTION submit_registration(uuid,text,text,text,text)                              TO anon;
GRANT EXECUTE ON FUNCTION admin_get_reg_events(text)                                                  TO anon;
GRANT EXECUTE ON FUNCTION admin_get_reg_entries(text,uuid)                                            TO anon;
GRANT EXECUTE ON FUNCTION admin_create_reg_event(text,text,date,text,text,text,integer,timestamptz)  TO anon;
GRANT EXECUTE ON FUNCTION admin_update_reg_event(text,uuid,text,date,text,text,text,integer,boolean,timestamptz) TO anon;
GRANT EXECUTE ON FUNCTION admin_delete_reg_event(text,uuid)                                           TO anon;
GRANT EXECUTE ON FUNCTION admin_delete_reg_entry(text,uuid)                                           TO anon;
