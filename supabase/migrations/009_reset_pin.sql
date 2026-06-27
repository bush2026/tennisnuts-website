-- 009_reset_pin.sql
-- Self-service PIN reset using email + display name as identity.
-- If both match an active member record, the PIN is updated and
-- all existing sessions are invalidated (forces fresh login).
-- Run in Supabase SQL Editor after migrations 001–008.

CREATE OR REPLACE FUNCTION reset_pin_with_identity(
  p_email        text,
  p_display_name text,
  p_new_pin_hash text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_member_id uuid;
BEGIN
  p_email        := lower(trim(p_email));
  p_display_name := trim(p_display_name);

  IF p_email = '' OR p_display_name = '' OR p_new_pin_hash = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'All fields are required');
  END IF;

  SELECT id INTO v_member_id
  FROM members
  WHERE email             = p_email
    AND lower(display_name) = lower(p_display_name)
    AND is_active         = true;

  IF v_member_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'No account found matching that email and name — check for typos'
    );
  END IF;

  UPDATE members SET pin_hash = p_new_pin_hash WHERE id = v_member_id;

  -- Invalidate all active sessions so existing logins must re-authenticate
  DELETE FROM member_sessions WHERE member_id = v_member_id;

  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION reset_pin_with_identity(text, text, text) TO anon;
