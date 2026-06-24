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

-- ── BETTER AUTH ERRORS ────────────────────────────────────────────────────────
-- Replace generic "Invalid email or PIN" with specific per-case messages
-- Adds a 'code' field so the UI can offer smart actions (e.g. "Register instead?")

CREATE OR REPLACE FUNCTION authenticate_member(p_email text, p_pin_hash text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_member members%ROWTYPE;
  v_token  text;
BEGIN
  p_email := lower(trim(p_email));

  IF NOT EXISTS (SELECT 1 FROM members WHERE email = p_email) THEN
    RETURN jsonb_build_object(
      'success', false, 'code', 'EMAIL_NOT_FOUND',
      'message', 'No account found for this email.'
    );
  END IF;

  IF EXISTS (SELECT 1 FROM members WHERE email = p_email AND is_active = false) THEN
    RETURN jsonb_build_object(
      'success', false, 'code', 'INACTIVE',
      'message', 'Your account is inactive — contact admin.'
    );
  END IF;

  SELECT * INTO v_member FROM members
  WHERE email = p_email AND pin_hash = p_pin_hash AND is_active = true;

  IF v_member.id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 'code', 'WRONG_PIN',
      'message', 'Incorrect PIN — please try again.'
    );
  END IF;

  DELETE FROM member_sessions WHERE member_id = v_member.id AND expires_at < now();
  INSERT INTO member_sessions (member_id, is_admin)
  VALUES (v_member.id, v_member.is_admin)
  RETURNING session_token INTO v_token;

  RETURN jsonb_build_object(
    'success',       true,
    'session_token', v_token,
    'member_id',     v_member.id,
    'display_name',  v_member.display_name,
    'is_admin',      v_member.is_admin
  );
END;
$$;

GRANT EXECUTE ON FUNCTION authenticate_member(text, text) TO anon;
