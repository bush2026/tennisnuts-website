-- 007_server_side_validations.sql
-- Close server-side gaps identified in audit:
-- 1. upsert_prediction: block hidden matches + enforce is_accepting_entries
-- 2. admin_enter_result: block hidden matches
-- 3. admin_get_all_predictions: filter hidden matches from audit view
-- Run in Supabase SQL Editor after migrations 001–006

-- ── FIX 1: upsert_prediction ─────────────────────────────────────────────────
-- Added checks (in order):
--   a. Match is not hidden
--   b. Tournament is accepting entries
-- (Lock time check kept as-is; set score validation unchanged)

CREATE OR REPLACE FUNCTION upsert_prediction(
  p_session_token  text,
  p_match_id       uuid,
  p_pick_winner    text,
  p_pick_set_score text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_member_id    uuid;
  v_match        matches%ROWTYPE;
  v_valid_scores text[];
BEGIN
  SELECT ms.member_id INTO v_member_id
  FROM member_sessions ms
  JOIN members mb ON mb.id = ms.member_id
  WHERE ms.session_token = p_session_token
    AND ms.expires_at > now()
    AND mb.is_active = true;

  IF v_member_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Not logged in');
  END IF;

  SELECT * INTO v_match FROM matches WHERE id = p_match_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Match not found');
  END IF;

  IF v_match.is_hidden THEN
    RETURN jsonb_build_object('success', false, 'message', 'This match is not available');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM tournaments WHERE id = v_match.tournament_id AND is_accepting_entries = true
  ) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Entries are closed for this tournament');
  END IF;

  IF v_match.lock_time <= now() THEN
    RETURN jsonb_build_object('success', false, 'message', 'Match is locked — predictions closed');
  END IF;

  IF p_pick_winner <> v_match.player1 AND p_pick_winner <> v_match.player2 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Invalid winner pick');
  END IF;

  IF p_pick_set_score IS NOT NULL THEN
    v_valid_scores := CASE v_match.format
      WHEN 'bo3' THEN ARRAY['2-0','2-1']
      ELSE ARRAY['3-0','3-1','3-2']
    END;
    IF NOT (p_pick_set_score = ANY(v_valid_scores)) THEN
      RETURN jsonb_build_object('success', false, 'message', 'Invalid set score for this format');
    END IF;
  END IF;

  INSERT INTO predictions (match_id, member_id, pick_winner, pick_set_score, updated_at)
  VALUES (p_match_id, v_member_id, p_pick_winner, p_pick_set_score, now())
  ON CONFLICT (match_id, member_id) DO UPDATE SET
    pick_winner    = EXCLUDED.pick_winner,
    pick_set_score = EXCLUDED.pick_set_score,
    updated_at     = now();

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ── FIX 2: admin_enter_result ────────────────────────────────────────────────
-- Block entering results for hidden matches (would silently score invalid predictions)

CREATE OR REPLACE FUNCTION admin_enter_result(
  p_session_token    text,
  p_match_id         uuid,
  p_result_winner    text,
  p_result_set_score text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_match        matches%ROWTYPE;
  v_valid_scores text[];
BEGIN
  PERFORM _assert_admin(p_session_token);

  SELECT * INTO v_match FROM matches WHERE id = p_match_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Match not found');
  END IF;

  IF v_match.is_hidden THEN
    RETURN jsonb_build_object('success', false, 'message', 'Cannot enter result for a hidden match — unhide it first');
  END IF;

  IF p_result_winner <> v_match.player1 AND p_result_winner <> v_match.player2 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Winner must be player1 or player2');
  END IF;

  v_valid_scores := CASE v_match.format
    WHEN 'bo3' THEN ARRAY['2-0','2-1']
    ELSE ARRAY['3-0','3-1','3-2']
  END;
  IF NOT (p_result_set_score = ANY(v_valid_scores)) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Invalid set score for format');
  END IF;

  UPDATE matches SET
    result_winner     = p_result_winner,
    result_set_score  = p_result_set_score,
    result_entered_at = now()
  WHERE id = p_match_id;

  UPDATE predictions p SET
    points_awarded = score_prediction(
      p_result_winner,    p_result_set_score,
      v_match.player1,    v_match.points_player1,
      v_match.points_player2, v_match.set_score_bonus,
      p.pick_winner,      p.pick_set_score
    )
  WHERE p.match_id = p_match_id;

  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- ── FIX 3: admin_get_all_predictions ─────────────────────────────────────────
-- Filter hidden matches — duplicate/error matches have no place in the audit record

CREATE OR REPLACE FUNCTION admin_get_all_predictions(
  p_session_token text,
  p_tournament_id uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb;
BEGIN
  PERFORM _assert_admin(p_session_token);

  SELECT jsonb_agg(
    jsonb_build_object(
      'id',               p.id,
      'member_name',      m.display_name,
      'match_label',      ma.player1 || ' vs ' || ma.player2,
      'tournament',       t.name,
      'pick_winner',      p.pick_winner,
      'pick_set_score',   p.pick_set_score,
      'points_awarded',   p.points_awarded,
      'created_at',       p.created_at,
      'updated_at',       p.updated_at,
      'result_winner',    ma.result_winner,
      'result_set_score', ma.result_set_score
    ) ORDER BY t.name, ma.player1, ma.player2, m.display_name
  )
  INTO v_result
  FROM predictions p
  JOIN members     m  ON m.id  = p.member_id
  JOIN matches     ma ON ma.id = p.match_id AND ma.is_hidden = false
  JOIN tournaments t  ON t.id  = ma.tournament_id
  WHERE (p_tournament_id IS NULL OR ma.tournament_id = p_tournament_id);

  RETURN COALESCE(v_result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('error', SQLERRM);
END;
$$;

-- ── GRANTS ────────────────────────────────────────────────────────────────────

GRANT EXECUTE ON FUNCTION upsert_prediction(text, uuid, text, text)  TO anon;
GRANT EXECUTE ON FUNCTION admin_enter_result(text, uuid, text, text) TO anon;
GRANT EXECUTE ON FUNCTION admin_get_all_predictions(text, uuid)      TO anon;
