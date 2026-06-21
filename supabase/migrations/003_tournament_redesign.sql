-- 003_tournament_redesign.sql
-- Simplify tournament model: is_visible + is_accepting_entries replace is_active
-- Run in Supabase SQL Editor after 001 and 002 migrations

-- ── NEW COLUMNS ──────────────────────────────────────────────────────────────

ALTER TABLE tournaments
  ADD COLUMN IF NOT EXISTS is_visible           boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_accepting_entries boolean NOT NULL DEFAULT false;

-- Migrate existing data from is_active
UPDATE tournaments SET
  is_visible           = is_active,
  is_accepting_entries = CASE WHEN status IN ('upcoming','live') AND is_active THEN true ELSE false END;

-- ── REPLACE ADMIN TOURNAMENT FUNCTIONS (new signatures) ──────────────────────

DROP FUNCTION IF EXISTS admin_add_tournament(text, text, text, boolean);
DROP FUNCTION IF EXISTS admin_update_tournament(text, uuid, text, text, boolean);

CREATE OR REPLACE FUNCTION admin_add_tournament(
  p_session_token        text,
  p_name                 text,
  p_status               text    DEFAULT 'upcoming',
  p_is_visible           boolean DEFAULT true,
  p_is_accepting_entries boolean DEFAULT true
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  PERFORM _assert_admin(p_session_token);
  IF p_status NOT IN ('upcoming','live','completed') THEN
    RETURN jsonb_build_object('success', false, 'message', 'Invalid status');
  END IF;
  INSERT INTO tournaments (name, status, is_visible, is_accepting_entries)
  VALUES (p_name, p_status, p_is_visible, p_is_accepting_entries)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

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
    is_accepting_entries = COALESCE(p_is_accepting_entries, is_accepting_entries)
  WHERE id = p_id;
  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- ── DAILY REPORT FUNCTION ────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION admin_get_daily_report(
  p_session_token text,
  p_tournament_id uuid,
  p_date          date DEFAULT CURRENT_DATE
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_tournament_name text;
  v_matches_data    jsonb;
  v_standings_data  jsonb;
BEGIN
  PERFORM _assert_admin(p_session_token);

  SELECT name INTO v_tournament_name FROM tournaments WHERE id = p_tournament_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Tournament not found');
  END IF;

  -- Matches with results entered on the given date (converted to IST = UTC+5:30)
  SELECT COALESCE(jsonb_agg(m_row ORDER BY entered_at ASC), '[]'::jsonb)
  INTO v_matches_data
  FROM (
    SELECT
      m.result_entered_at AS entered_at,
      jsonb_build_object(
        'player1',          m.player1,
        'player2',          m.player2,
        'format',           m.format,
        'result_winner',    m.result_winner,
        'result_set_score', m.result_set_score,
        'is_upset',         CASE
                              WHEN m.result_winner = m.player1 THEN m.points_player1 < m.points_player2
                              ELSE m.points_player2 < m.points_player1
                            END,
        'predictions',      COALESCE((
          SELECT jsonb_agg(jsonb_build_object(
            'name',    mb.display_name,
            'correct', p.pick_winner = m.result_winner,
            'pts',     p.points_awarded
          ) ORDER BY mb.display_name)
          FROM predictions p
          JOIN members mb ON mb.id = p.member_id AND mb.is_active = true
          WHERE p.match_id = m.id
        ), '[]'::jsonb)
      ) AS m_row
    FROM matches m
    WHERE m.tournament_id = p_tournament_id
      AND m.result_winner IS NOT NULL
      AND (m.result_entered_at AT TIME ZONE 'Asia/Kolkata')::date = p_date
  ) sub;

  -- Overall standings for this tournament
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object('name', display_name, 'pts', total_pts, 'rank', rnk)
    ORDER BY rnk, display_name
  ), '[]'::jsonb)
  INTO v_standings_data
  FROM (
    SELECT
      mb.display_name,
      SUM(p.points_awarded)::int AS total_pts,
      RANK() OVER (ORDER BY SUM(p.points_awarded) DESC) AS rnk
    FROM members mb
    JOIN predictions p  ON p.member_id  = mb.id
    JOIN matches mx     ON mx.id        = p.match_id AND mx.tournament_id = p_tournament_id
    WHERE mb.is_active = true
      AND p.points_awarded IS NOT NULL
    GROUP BY mb.id, mb.display_name
  ) s;

  RETURN jsonb_build_object(
    'tournament_name', v_tournament_name,
    'date',            p_date,
    'matches',         v_matches_data,
    'standings',       v_standings_data
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('error', SQLERRM);
END;
$$;

-- ── GRANTS ───────────────────────────────────────────────────────────────────

GRANT EXECUTE ON FUNCTION admin_add_tournament(text, text, text, boolean, boolean)           TO anon;
GRANT EXECUTE ON FUNCTION admin_update_tournament(text, uuid, text, text, boolean, boolean)  TO anon;
GRANT EXECUTE ON FUNCTION admin_get_daily_report(text, uuid, date)                           TO anon;
