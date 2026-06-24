-- 005_admin_get_predictions.sql
-- Read-only admin view of all prediction submissions (for audit/record purposes)
-- Run in Supabase SQL Editor after 004 migration

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
  JOIN matches     ma ON ma.id = p.match_id
  JOIN tournaments t  ON t.id  = ma.tournament_id
  WHERE (p_tournament_id IS NULL OR ma.tournament_id = p_tournament_id);

  RETURN COALESCE(v_result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION admin_get_all_predictions(text, uuid) TO anon;
