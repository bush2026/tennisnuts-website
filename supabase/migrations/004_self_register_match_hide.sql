-- 004_self_register_match_hide.sql
-- 1. Members can self-register (no admin required)
-- 2. Matches can be hidden by admin (soft-delete for duplicates)
-- Run in Supabase SQL Editor after 001, 002, 003 migrations

-- ── MATCH HIDE ────────────────────────────────────────────────────────────────

ALTER TABLE matches
  ADD COLUMN IF NOT EXISTS is_hidden boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION admin_toggle_match_hidden(
  p_session_token text,
  p_match_id      uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_hidden boolean;
BEGIN
  PERFORM _assert_admin(p_session_token);
  UPDATE matches SET is_hidden = NOT is_hidden
  WHERE id = p_match_id RETURNING is_hidden INTO v_hidden;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Match not found');
  END IF;
  RETURN jsonb_build_object('success', true, 'is_hidden', v_hidden);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- ── SELF-REGISTRATION ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION member_register(
  p_email        text,
  p_display_name text,
  p_pin_hash     text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  p_email        := lower(trim(p_email));
  p_display_name := trim(p_display_name);

  IF p_email = '' OR p_display_name = '' OR p_pin_hash = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'All fields are required');
  END IF;

  IF EXISTS (SELECT 1 FROM members WHERE email = p_email) THEN
    RETURN jsonb_build_object('success', false, 'message', 'An account with this email already exists');
  END IF;

  IF EXISTS (SELECT 1 FROM members WHERE lower(display_name) = lower(p_display_name)) THEN
    RETURN jsonb_build_object('success', false, 'message', 'This display name is already taken — try adding your initial or city');
  END IF;

  INSERT INTO members (email, display_name, pin_hash, is_active)
  VALUES (p_email, p_display_name, p_pin_hash, true)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- ── GRANTS ────────────────────────────────────────────────────────────────────

GRANT EXECUTE ON FUNCTION admin_toggle_match_hidden(text, uuid) TO anon;
GRANT EXECUTE ON FUNCTION member_register(text, text, text)     TO anon;
