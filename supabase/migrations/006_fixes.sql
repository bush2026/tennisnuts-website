-- 006_fixes.sql
-- Fixes:
-- 1. Sync is_active to match is_visible for all existing tournaments
--    (is_active was the original column; is_visible replaced it in migration 003
--     but admin_update_tournament never kept is_active in sync)
-- 2. Update admin_update_tournament to keep is_active in sync going forward
-- 3. Exclude hidden matches from tournament_leaderboard view
-- 4. Exclude hidden matches from get_my_predictions function
-- Run in Supabase SQL Editor after migrations 001–005

-- ── FIX 1: Data sync — align is_active with is_visible ──────────────────────

UPDATE tournaments SET is_active = is_visible;

-- ── FIX 2: Keep is_active in sync when admin toggles visibility ───────────────

CREATE OR REPLACE FUNCTION admin_update_tournament(
  p_session_token        text,
  p_id                   uuid,
  p_name                 text    DEFAULT NULL,
  p_status               text    DEFAULT NULL,
  p_is_visible           boolean DEFAULT NULL,
  p_is_accepting_entries boolean DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM _assert_admin(p_session_token);
  UPDATE tournaments SET
    name                 = COALESCE(p_name,                 name),
    status               = COALESCE(p_status,               status),
    is_visible           = COALESCE(p_is_visible,           is_visible),
    is_accepting_entries = COALESCE(p_is_accepting_entries, is_accepting_entries),
    is_active            = COALESCE(p_is_visible,           is_visible)  -- keep in sync
  WHERE id = p_id;
  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION admin_update_tournament(text, uuid, text, text, boolean, boolean) TO anon;

-- ── FIX 3: Leaderboard — exclude hidden matches ───────────────────────────────

CREATE OR REPLACE VIEW tournament_leaderboard AS
  SELECT
    m.tournament_id,
    p.member_id,
    mb.display_name,
    COALESCE(SUM(p.points_awarded), 0)::int AS total_points
  FROM matches m
  JOIN predictions p  ON p.match_id = m.id
  JOIN members     mb ON mb.id = p.member_id
  WHERE mb.is_active = true
    AND p.points_awarded IS NOT NULL
    AND m.is_hidden = false
  GROUP BY m.tournament_id, p.member_id, mb.display_name;

-- ── FIX 4: get_my_predictions — exclude hidden matches ────────────────────────

CREATE OR REPLACE FUNCTION get_my_predictions(p_session_token text, p_tournament_id uuid)
RETURNS TABLE (
  prediction_id    uuid,
  match_id         uuid,
  player1          text,
  player2          text,
  format           text,
  points_player1   int,
  points_player2   int,
  set_score_bonus  int,
  lock_time        timestamptz,
  pick_winner      text,
  pick_set_score   text,
  points_awarded   int,
  result_winner    text,
  result_set_score text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_member_id uuid;
BEGIN
  SELECT ms.member_id INTO v_member_id
  FROM member_sessions ms
  WHERE ms.session_token = p_session_token AND ms.expires_at > now();

  IF v_member_id IS NULL THEN RETURN; END IF;

  RETURN QUERY
    SELECT
      p.id,             m.id,
      m.player1,        m.player2,
      m.format,         m.points_player1,
      m.points_player2, m.set_score_bonus,
      m.lock_time,      p.pick_winner,
      p.pick_set_score, p.points_awarded,
      m.result_winner,  m.result_set_score
    FROM matches m
    LEFT JOIN predictions p ON p.match_id = m.id AND p.member_id = v_member_id
    WHERE m.tournament_id = p_tournament_id
      AND m.is_hidden = false
    ORDER BY m.lock_time ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_my_predictions(text, uuid) TO anon;
