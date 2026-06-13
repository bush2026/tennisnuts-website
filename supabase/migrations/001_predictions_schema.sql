-- Tennisnuts Grand Slam Predictions — Schema v1
-- Apply in Supabase SQL Editor or via: supabase db push

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS tournaments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  status      text NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'live', 'completed')),
  is_active   boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS members (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         text NOT NULL UNIQUE,
  display_name  text NOT NULL UNIQUE,
  pin_hash      text NOT NULL,
  is_admin      boolean NOT NULL DEFAULT false,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS matches (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id     uuid NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  player1           text NOT NULL,
  player2           text NOT NULL,
  format            text NOT NULL CHECK (format IN ('bo3', 'bo5')),
  points_player1    int NOT NULL CHECK (points_player1 >= 0),
  points_player2    int NOT NULL CHECK (points_player2 >= 0),
  set_score_bonus   int NOT NULL DEFAULT 0 CHECK (set_score_bonus >= 0),
  lock_time         timestamptz NOT NULL,
  result_winner     text,
  result_set_score  text,
  result_entered_at timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT result_winner_valid CHECK (
    result_winner IS NULL OR result_winner = player1 OR result_winner = player2
  )
);

CREATE TABLE IF NOT EXISTS predictions (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id       uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  member_id      uuid NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  pick_winner    text NOT NULL,
  pick_set_score text,
  points_awarded int,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (match_id, member_id)
);

-- Sessions table (custom auth, no Supabase Auth)
CREATE TABLE IF NOT EXISTS member_sessions (
  session_token text PRIMARY KEY DEFAULT encode(gen_random_bytes(32), 'hex'),
  member_id     uuid NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  is_admin      boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now(),
  expires_at    timestamptz NOT NULL DEFAULT now() + interval '7 days'
);

-- ============================================================
-- VIEWS
-- ============================================================

-- Public-safe member view (no email, no pin_hash)
CREATE OR REPLACE VIEW public_members AS
  SELECT id, display_name, is_active FROM members;

-- Leaderboard per tournament
CREATE OR REPLACE VIEW tournament_leaderboard AS
  SELECT
    m.tournament_id,
    p.member_id,
    mb.display_name,
    COALESCE(SUM(p.points_awarded), 0)::int AS total_points
  FROM matches m
  JOIN predictions p ON p.match_id = m.id
  JOIN members mb ON mb.id = p.member_id
  WHERE mb.is_active = true
    AND p.points_awarded IS NOT NULL
  GROUP BY m.tournament_id, p.member_id, mb.display_name;

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE tournaments      ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches           ENABLE ROW LEVEL SECURITY;
ALTER TABLE members           ENABLE ROW LEVEL SECURITY;
ALTER TABLE predictions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_sessions   ENABLE ROW LEVEL SECURITY;

-- Tournaments & matches: public read only
CREATE POLICY "tournaments_public_read" ON tournaments
  FOR SELECT TO anon USING (true);

CREATE POLICY "matches_public_read" ON matches
  FOR SELECT TO anon USING (true);

-- Members: no direct anon access (sensitive columns: email, pin_hash)
-- All member data flows through security-definer functions or public_members view

-- Predictions: public read only for locked matches (hides picks before lock)
CREATE POLICY "predictions_read_after_lock" ON predictions
  FOR SELECT TO anon
  USING (
    EXISTS (
      SELECT 1 FROM matches m
      WHERE m.id = predictions.match_id
        AND m.lock_time <= now()
    )
  );

-- member_sessions: no direct access
-- (no policies = deny all for anon)

-- ============================================================
-- GRANTS
-- ============================================================

GRANT SELECT ON tournaments TO anon;
GRANT SELECT ON matches TO anon;
GRANT SELECT ON public_members TO anon;
GRANT SELECT ON tournament_leaderboard TO anon;
GRANT SELECT ON predictions TO anon;

-- ============================================================
-- SECURITY DEFINER FUNCTIONS
-- ============================================================

-- Authenticate member: returns session token on success
CREATE OR REPLACE FUNCTION authenticate_member(p_email text, p_pin_hash text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_member  members%ROWTYPE;
  v_token   text;
BEGIN
  p_email := lower(trim(p_email));
  SELECT * INTO v_member FROM members
  WHERE email = p_email AND pin_hash = p_pin_hash AND is_active = true;

  IF v_member.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Invalid email or PIN');
  END IF;

  -- Expire old sessions for this member
  DELETE FROM member_sessions WHERE member_id = v_member.id AND expires_at < now();

  INSERT INTO member_sessions (member_id, is_admin)
  VALUES (v_member.id, v_member.is_admin)
  RETURNING session_token INTO v_token;

  RETURN jsonb_build_object(
    'success',      true,
    'session_token', v_token,
    'member_id',    v_member.id,
    'display_name', v_member.display_name,
    'is_admin',     v_member.is_admin
  );
END;
$$;

-- Validate session (used on page load to restore state)
CREATE OR REPLACE FUNCTION validate_session(p_session_token text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_row record;
BEGIN
  SELECT ms.member_id, mb.display_name, ms.is_admin
  INTO v_row
  FROM member_sessions ms
  JOIN members mb ON mb.id = ms.member_id
  WHERE ms.session_token = p_session_token
    AND ms.expires_at > now()
    AND mb.is_active = true;

  IF v_row IS NULL THEN
    RETURN jsonb_build_object('valid', false);
  END IF;

  RETURN jsonb_build_object(
    'valid',        true,
    'member_id',    v_row.member_id,
    'display_name', v_row.display_name,
    'is_admin',     v_row.is_admin
  );
END;
$$;

-- Logout
CREATE OR REPLACE FUNCTION logout_member(p_session_token text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  DELETE FROM member_sessions WHERE session_token = p_session_token;
END;
$$;

-- Upsert prediction (enforces lock time server-side)
CREATE OR REPLACE FUNCTION upsert_prediction(
  p_session_token  text,
  p_match_id       uuid,
  p_pick_winner    text,
  p_pick_set_score text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
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

  -- Server-side lock enforcement (spec §9)
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

-- Score a single prediction (pure function, single source of truth per spec §7)
CREATE OR REPLACE FUNCTION score_prediction(
  p_result_winner    text,
  p_result_set_score text,
  p_player1          text,
  p_points_player1   int,
  p_points_player2   int,
  p_set_score_bonus  int,
  p_pick_winner      text,
  p_pick_set_score   text
)
RETURNS int
LANGUAGE plpgsql IMMUTABLE SET search_path = public AS $$
DECLARE
  v_pts int := 0;
BEGIN
  IF (p_pick_winner = p_result_winner) THEN
    v_pts := CASE WHEN p_result_winner = p_player1
                  THEN p_points_player1
                  ELSE p_points_player2 END;
    IF p_pick_set_score IS NOT NULL AND p_pick_set_score = p_result_set_score THEN
      v_pts := v_pts + p_set_score_bonus;
    END IF;
  END IF;
  RETURN v_pts;
END;
$$;

-- Get own predictions with match context
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
      p.id,         m.id,
      m.player1,    m.player2,
      m.format,     m.points_player1,
      m.points_player2, m.set_score_bonus,
      m.lock_time,  p.pick_winner,
      p.pick_set_score, p.points_awarded,
      m.result_winner, m.result_set_score
    FROM matches m
    LEFT JOIN predictions p ON p.match_id = m.id AND p.member_id = v_member_id
    WHERE m.tournament_id = p_tournament_id
    ORDER BY m.lock_time ASC;
END;
$$;

-- ============================================================
-- ADMIN FUNCTIONS (all require is_admin session)
-- ============================================================

-- Helper: assert admin session, returns member_id or raises
CREATE OR REPLACE FUNCTION _assert_admin(p_token text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  SELECT ms.member_id INTO v_id
  FROM member_sessions ms
  WHERE ms.session_token = p_token AND ms.expires_at > now() AND ms.is_admin = true;
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'admin_required';
  END IF;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION admin_add_tournament(
  p_session_token text,
  p_name          text,
  p_status        text DEFAULT 'upcoming',
  p_is_active     boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  PERFORM _assert_admin(p_session_token);
  IF p_status NOT IN ('upcoming','live','completed') THEN
    RETURN jsonb_build_object('success', false, 'message', 'Invalid status');
  END IF;
  IF p_is_active THEN UPDATE tournaments SET is_active = false; END IF;
  INSERT INTO tournaments (name, status, is_active)
  VALUES (p_name, p_status, p_is_active) RETURNING id INTO v_id;
  RETURN jsonb_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION admin_update_tournament(
  p_session_token text,
  p_id            uuid,
  p_name          text DEFAULT NULL,
  p_status        text DEFAULT NULL,
  p_is_active     boolean DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM _assert_admin(p_session_token);
  IF p_is_active IS TRUE THEN UPDATE tournaments SET is_active = false; END IF;
  UPDATE tournaments SET
    name      = COALESCE(p_name,      name),
    status    = COALESCE(p_status,    status),
    is_active = COALESCE(p_is_active, is_active)
  WHERE id = p_id;
  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION admin_add_match(
  p_session_token   text,
  p_tournament_id   uuid,
  p_player1         text,
  p_player2         text,
  p_format          text,
  p_points_player1  int,
  p_points_player2  int,
  p_set_score_bonus int,
  p_lock_time       timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  PERFORM _assert_admin(p_session_token);
  INSERT INTO matches (tournament_id, player1, player2, format,
                       points_player1, points_player2, set_score_bonus, lock_time)
  VALUES (p_tournament_id, p_player1, p_player2, p_format,
          p_points_player1, p_points_player2, p_set_score_bonus, p_lock_time)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION admin_update_match(
  p_session_token   text,
  p_match_id        uuid,
  p_player1         text DEFAULT NULL,
  p_player2         text DEFAULT NULL,
  p_format          text DEFAULT NULL,
  p_points_player1  int DEFAULT NULL,
  p_points_player2  int DEFAULT NULL,
  p_set_score_bonus int DEFAULT NULL,
  p_lock_time       timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM _assert_admin(p_session_token);
  UPDATE matches SET
    player1          = COALESCE(p_player1,         player1),
    player2          = COALESCE(p_player2,         player2),
    format           = COALESCE(p_format,          format),
    points_player1   = COALESCE(p_points_player1,  points_player1),
    points_player2   = COALESCE(p_points_player2,  points_player2),
    set_score_bonus  = COALESCE(p_set_score_bonus, set_score_bonus),
    lock_time        = COALESCE(p_lock_time,       lock_time)
  WHERE id = p_match_id;
  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION admin_enter_result(
  p_session_token    text,
  p_match_id         uuid,
  p_result_winner    text,
  p_result_set_score text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_match matches%ROWTYPE;
  v_valid_scores text[];
BEGIN
  PERFORM _assert_admin(p_session_token);

  SELECT * INTO v_match FROM matches WHERE id = p_match_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Match not found');
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

  -- Auto-score every prediction for this match (spec §7)
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

CREATE OR REPLACE FUNCTION admin_add_member(
  p_session_token text,
  p_email         text,
  p_display_name  text,
  p_pin_hash      text,
  p_is_admin      boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  PERFORM _assert_admin(p_session_token);
  INSERT INTO members (email, display_name, pin_hash, is_admin)
  VALUES (lower(trim(p_email)), p_display_name, p_pin_hash, p_is_admin)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('success', true, 'id', v_id);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success', false, 'message', 'Email or display name already exists');
WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION admin_reset_member_pin(
  p_session_token text,
  p_member_id     uuid,
  p_new_pin_hash  text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM _assert_admin(p_session_token);
  UPDATE members SET pin_hash = p_new_pin_hash WHERE id = p_member_id;
  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION admin_set_member_active(
  p_session_token text,
  p_member_id     uuid,
  p_is_active     boolean
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM _assert_admin(p_session_token);
  UPDATE members SET is_active = p_is_active WHERE id = p_member_id;
  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION admin_get_members(p_session_token text)
RETURNS TABLE (
  id           uuid,
  email        text,
  display_name text,
  is_admin     boolean,
  is_active    boolean,
  created_at   timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM _assert_admin(p_session_token);
  RETURN QUERY
    SELECT m.id, m.email, m.display_name, m.is_admin, m.is_active, m.created_at
    FROM members m ORDER BY m.created_at;
END;
$$;

-- ============================================================
-- GRANTS — all exec via anon (security enforced inside functions)
-- ============================================================

GRANT EXECUTE ON FUNCTION authenticate_member(text, text)                                          TO anon;
GRANT EXECUTE ON FUNCTION validate_session(text)                                                    TO anon;
GRANT EXECUTE ON FUNCTION logout_member(text)                                                       TO anon;
GRANT EXECUTE ON FUNCTION upsert_prediction(text, uuid, text, text)                                TO anon;
GRANT EXECUTE ON FUNCTION get_my_predictions(text, uuid)                                            TO anon;
GRANT EXECUTE ON FUNCTION admin_add_tournament(text, text, text, boolean)                           TO anon;
GRANT EXECUTE ON FUNCTION admin_update_tournament(text, uuid, text, text, boolean)                  TO anon;
GRANT EXECUTE ON FUNCTION admin_add_match(text, uuid, text, text, text, int, int, int, timestamptz) TO anon;
GRANT EXECUTE ON FUNCTION admin_update_match(text, uuid, text, text, text, int, int, int, timestamptz) TO anon;
GRANT EXECUTE ON FUNCTION admin_enter_result(text, uuid, text, text)                                TO anon;
GRANT EXECUTE ON FUNCTION admin_add_member(text, text, text, text, boolean)                         TO anon;
GRANT EXECUTE ON FUNCTION admin_reset_member_pin(text, uuid, text)                                  TO anon;
GRANT EXECUTE ON FUNCTION admin_set_member_active(text, uuid, boolean)                              TO anon;
GRANT EXECUTE ON FUNCTION admin_get_members(text)                                                   TO anon;
