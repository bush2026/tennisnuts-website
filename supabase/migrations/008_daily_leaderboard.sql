-- 008_daily_leaderboard.sql
-- Public function returning per-day standings for a tournament.
-- Groups points by the date the result was entered (IST = Asia/Kolkata).
-- Run in Supabase SQL Editor after migrations 001–007.

CREATE OR REPLACE FUNCTION get_daily_leaderboard(p_tournament_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb;
BEGIN
  -- Step 1: aggregate each member's points per calendar day (IST)
  -- Step 2: rank within each day by points desc
  -- Step 3: group into per-day objects with standings array
  WITH per_member AS (
    SELECT
      (ma.result_entered_at AT TIME ZONE 'Asia/Kolkata')::date AS day_date,
      mb.id                                                                  AS member_id,
      mb.display_name,
      SUM(p.points_awarded)::int                                            AS day_points,
      COUNT(*) FILTER (WHERE p.points_awarded > 0)::int                    AS correct_picks,
      COUNT(*)::int                                                          AS total_picks
    FROM predictions  p
    JOIN members      mb ON mb.id = p.member_id AND mb.is_active = true
    JOIN matches      ma ON ma.id = p.match_id
      AND ma.tournament_id  = p_tournament_id
      AND ma.is_hidden      = false
      AND ma.result_winner IS NOT NULL
    WHERE p.points_awarded IS NOT NULL
    GROUP BY
      (ma.result_entered_at AT TIME ZONE 'Asia/Kolkata')::date,
      mb.id, mb.display_name
  ),
  ranked AS (
    SELECT *,
      RANK() OVER (PARTITION BY day_date ORDER BY day_points DESC) AS day_rank
    FROM per_member
  )
  SELECT jsonb_agg(day_obj ORDER BY day_date)
  INTO v_result
  FROM (
    SELECT
      day_date,
      jsonb_build_object(
        'date',      day_date,
        'standings', jsonb_agg(
          jsonb_build_object(
            'member_id',     member_id,
            'rank',          day_rank,
            'member_name',   display_name,
            'day_points',    day_points,
            'correct_picks', correct_picks,
            'total_picks',   total_picks
          ) ORDER BY day_rank, display_name
        )
      ) AS day_obj
    FROM ranked
    GROUP BY day_date
  ) by_day;

  RETURN COALESCE(v_result, '[]'::jsonb);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION get_daily_leaderboard(uuid) TO anon;
