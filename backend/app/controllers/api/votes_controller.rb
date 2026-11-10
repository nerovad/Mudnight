# Port of backend/src/controllers/voteController.ts.
#
# The Express routes had no auth middleware, so `(req as any).user?.id || 1`
# always resolved to user 1. That is preserved: every ballot is user 1's.
module Api
  class VotesController < ApplicationController
    ANONYMOUS_USER_ID = 1 # "replace with real auth later" (Express)

    # POST /api/sessions/:sessionId/entries/:entryId/rate
    def rate_entry
      session_id = js_number_param(params[:sessionId])
      entry_id = js_number_param(params[:entryId])
      score = body["score"]
      user_id = ANONYMOUS_USER_ID

      ballot = Db.one(
        "INSERT INTO ballots (session_id, user_id, weight)
VALUES ($1, $2, 1.0)
ON CONFLICT (session_id, user_id) DO UPDATE SET user_id = EXCLUDED.user_id
RETURNING id",
        [session_id, user_id]
      )

      Db.query(
        "INSERT INTO ratings (session_id, entry_id, ballot_id, score)
VALUES ($1, $2, $3, $4)
ON CONFLICT (session_id, entry_id, ballot_id)
DO UPDATE SET score = EXCLUDED.score, created_at = now()",
        [session_id, entry_id, ballot["id"], score]
      )

      render json: { ok: true }
    rescue StandardError => e
      Rails.logger.error("Error rating: #{e.message}")
      render json: { error: "Error saving rating" }, status: :internal_server_error
    end

    # GET /api/sessions/:sessionId/leaderboard
    def leaderboard
      rows = Db.query(
        "SELECT
se.id AS entry_id,
f.title,
ROUND(SUM(r.score * COALESCE(b.weight,1)) / NULLIF(SUM(COALESCE(b.weight,1)),0), 3) AS weighted_avg,
COUNT(*) AS votes
FROM ratings r
JOIN ballots b ON (b.session_id = r.session_id AND b.id = r.ballot_id)
JOIN session_entries se ON se.id = r.entry_id
JOIN films f ON f.id = se.film_id
WHERE r.session_id = $1
GROUP BY se.id, f.title
ORDER BY weighted_avg DESC, votes DESC",
        [js_number_param(params[:sessionId])]
      ).rows

      render json: rows
    rescue StandardError => e
      Rails.logger.error("Error leaderboard: #{e.message}")
      render json: { error: "Error fetching leaderboard" }, status: :internal_server_error
    end

    # POST /api/ratings  Body: { channel, film_id, score }
    def create_rating
      b = body
      channel = b["channel"]
      film_id = b["film_id"]
      score = b["score"]

      if Js.falsy?(channel) || Js.falsy?(film_id) || !score.is_a?(Numeric) || score < 1 || score > 10
        return render json: { error: "invalid_payload" }, status: :bad_request
      end

      resolved = resolve_session_and_entry_id(channel, js_number_param(film_id))
      return render json: { error: "session_or_entry_not_found" }, status: :bad_request unless resolved

      session_id, entry_id = resolved
      user_id = ANONYMOUS_USER_ID

      ua = request.user_agent.to_s
      forwarded = request.headers["X-Forwarded-For"].to_s.split(",")[0].to_s.strip
      ip = forwarded.empty? ? request.remote_addr.to_s : forwarded
      fingerprint = Digest::SHA256.hexdigest("#{ip}|#{ua}|#{user_id}")

      ballot = Db.one(
        "INSERT INTO ballots (session_id, user_id, fingerprint_sha256, weight)
       VALUES ($1, $2, $3, 1.0)
       ON CONFLICT (session_id, user_id) DO UPDATE SET user_id = EXCLUDED.user_id
       RETURNING id",
        [session_id, user_id, fingerprint]
      )

      Db.query(
        "INSERT INTO ratings (session_id, entry_id, ballot_id, score)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (session_id, entry_id, ballot_id)
       DO UPDATE SET score = EXCLUDED.score, created_at = now()",
        [session_id, entry_id, ballot["id"], score]
      )

      render json: { ok: true }, status: :created
    rescue StandardError => e
      Rails.logger.error("Error rating (adapter): #{e.message}")
      render json: { error: "Error saving rating" }, status: :internal_server_error
    end

    private

    # channel -> active (else latest) session -> entry for film
    def resolve_session_and_entry_id(channel_key, film_id)
      ch = Db.query("SELECT id FROM channels WHERE slug=$1 OR name=$1 OR stream_key=$1 LIMIT 1", [channel_key])
      return nil if ch.row_count.zero?

      channel_id = ch.rows[0]["id"]

      now_iso = Time.now.utc.iso8601(3)
      active = Db.query(
        "SELECT id FROM sessions
        WHERE channel_id=$1
          AND starts_at <= $2
          AND (ends_at IS NULL OR ends_at >= $2)
        ORDER BY starts_at DESC
        LIMIT 1",
        [channel_id, now_iso]
      )
      session_id = active.row_count.positive? ? active.rows[0]["id"] : nil

      if Js.falsy?(session_id)
        latest = Db.query("SELECT id FROM sessions WHERE channel_id=$1 ORDER BY starts_at DESC LIMIT 1", [channel_id])
        session_id = latest.row_count.positive? ? latest.rows[0]["id"] : nil
      end
      return nil if Js.falsy?(session_id)

      entry = Db.query("SELECT id FROM session_entries WHERE session_id=$1 AND film_id=$2 LIMIT 1", [session_id, film_id])
      return nil if entry.row_count.zero?

      [session_id, entry.rows[0]["id"]]
    end

    def js_number_param(value)
      n = Js.number(value)
      return "NaN" if n.nil?

      n.is_a?(Float) && n.finite? && n == n.floor && n.abs < 1e21 ? n.to_i : n
    end
  end
end
