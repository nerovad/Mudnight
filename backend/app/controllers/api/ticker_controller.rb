# Port of controllers/tickerController.ts + routes/tickerRoutes.ts.
# Ticker content: our own editorial lines plus at most one paid sponsor slot.
module Api
  class TickerController < ApplicationController
    # Guards are per-route rather than blanket, because GET / is public — the
    # player fetches it with no token.
    before_action :authenticate_token!, except: :index
    before_action -> { require_group!("super_admin") }, except: :index

    # A row is live when it is switched on and now falls inside its flight window.
    LIVE_PREDICATE = <<~SQL.freeze
      active
        AND (starts_at IS NULL OR starts_at <= now())
        AND (ends_at   IS NULL OR ends_at   >  now())
    SQL

    # Characters removed by String.prototype.trim().
    JS_TRIM = /\A[\t\n\v\f\r \u{00a0}\u{1680}\u{2000}-\u{200a}\u{2028}\u{2029}\u{202f}\u{205f}\u{3000}\u{feff}]+|[\t\n\v\f\r \u{00a0}\u{1680}\u{2000}-\u{200a}\u{2028}\u{2029}\u{202f}\u{205f}\u{3000}\u{feff}]+\z/

    # GET /api/ticker — public. Every live segment in loop order, with the
    # one-sponsor-at-a-time rule applied here rather than in the schema.
    #
    # If two sponsor flights overlap (a booking mistake), the higher priority
    # wins and the loser is dropped rather than both running.
    def index
      rows = Db.query(<<~SQL).rows
        SELECT id, kind, body, sponsor_name, link_url
                 FROM ticker_messages
                WHERE #{LIVE_PREDICATE}
                ORDER BY priority DESC, id ASC
      SQL

      segments = []
      sponsor_taken = false

      rows.each do |row|
        if row["kind"] == "sponsor"
          next if sponsor_taken

          sponsor_taken = true
        end
        segments << to_public_segment(row)
      end

      # Short cache, but not none — this is hit on every page load.
      response.set_header("Cache-Control", "public, max-age=60")
      render json: { segments: segments }
    end

    # GET /api/ticker/all — admin. Every row including inactive and expired.
    def all
      rows = Db.query(<<~SQL).rows
        SELECT id, kind, body, sponsor_name, link_url, priority, active,
                      starts_at, ends_at, created_at, updated_at
                 FROM ticker_messages
                ORDER BY priority DESC, id ASC
      SQL
      render json: rows
    end

    # POST /api/ticker — admin. Create a segment.
    def create
      result = normalize(body)
      return render(json: { error: result[:error] }, status: :bad_request) if result[:error]

      v = result[:values]
      rows = Db.query(<<~SQL, [v[:kind], v[:body], v[:sponsor_name], v[:link_url], v[:priority], v[:active], v[:starts_at], v[:ends_at]]).rows
        INSERT INTO ticker_messages
                 (kind, body, sponsor_name, link_url, priority, active, starts_at, ends_at)
               VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
               RETURNING *
      SQL
      render json: rows[0], status: :created
    end

    # PUT /api/ticker/:id — admin. Full replace of a segment.
    def update
      id = Js.number(params[:id])
      result = normalize(body)
      return render(json: { error: result[:error] }, status: :bad_request) if result[:error]

      v = result[:values]
      rows = Db.query(<<~SQL, [v[:kind], v[:body], v[:sponsor_name], v[:link_url], v[:priority], v[:active], v[:starts_at], v[:ends_at], id]).rows
        UPDATE ticker_messages
                  SET kind = $1, body = $2, sponsor_name = $3, link_url = $4,
                      priority = $5, active = $6, starts_at = $7, ends_at = $8,
                      updated_at = now()
                WHERE id = $9
              RETURNING *
      SQL
      return render(json: { error: "Ticker message not found" }, status: :not_found) if rows.empty?

      render json: rows[0]
    end

    # DELETE /api/ticker/:id — admin.
    def destroy
      id = Js.number(params[:id])
      result = Db.query("DELETE FROM ticker_messages WHERE id = $1", [id])
      return render(json: { error: "Ticker message not found" }, status: :not_found) if result.row_count.zero?

      head :no_content
    end

    private

    # Shape sent to the player. Deliberately narrow — no flight dates, no
    # priority, nothing a viewer has no business seeing.
    def to_public_segment(row)
      {
        id: Js.number(row["id"]),
        kind: row["kind"],
        body: row["body"],
        sponsorName: row["sponsor_name"],
        linkUrl: row["link_url"]
      }
    end

    # (x ?? "").trim() — a non-string x throws a TypeError in the JS. (In
    # Express that was an unhandled rejection; here it becomes a 500.)
    def js_trim(value)
      value = "" if value.nil?
      raise TypeError, "trim is not a function" unless value.is_a?(String)

      value.gsub(JS_TRIM, "")
    end

    # trimmed || null
    def empty_to_nil(str) = str.empty? ? nil : str

    # new Date(x) as epoch seconds, or nil for an Invalid Date.
    def js_date(value)
      case value
      when Numeric then value.to_f / 1000
      when true then 0.001
      when String
        str = value.strip
        # ISO date-only forms are UTC in JS; everything else is local time.
        if str.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          Time.utc(*str.split("-").map(&:to_i)).to_f
        else
          Time.parse(str).to_f
        end
      end
    rescue ArgumentError, RangeError
      nil
    end

    # Validate and normalize a write. Returns { error: } or { values: }. The
    # CHECK constraints in the schema are the real backstop; this exists to
    # return a usable message instead of a 500.
    def normalize(input)
      kind = input["kind"] == "sponsor" ? "sponsor" : "editorial"
      body_text = js_trim(input["body"])
      return { error: "body is required" } if body_text.empty?

      sponsor_name = empty_to_nil(js_trim(input["sponsorName"]))
      if kind == "sponsor" && !sponsor_name
        return { error: "sponsorName is required for a sponsor segment" }
      end

      link_url = empty_to_nil(js_trim(input["linkUrl"]))
      if link_url && !link_url.match?(%r{\Ahttps?://}i)
        # Anything else (javascript:, data:) would become an XSS vector the
        # moment it is rendered into an href.
        return { error: "linkUrl must be an http(s) URL" }
      end

      starts_at = Js.truthy?(input["startsAt"]) ? input["startsAt"] : nil
      ends_at = Js.truthy?(input["endsAt"]) ? input["endsAt"] : nil
      if starts_at && ends_at
        ends_t = js_date(ends_at)
        starts_t = js_date(starts_at)
        return { error: "endsAt must be after startsAt" } if ends_t && starts_t && ends_t <= starts_t
      end

      priority = Js.number(input["priority"])
      priority = priority.to_i if priority.is_a?(Float) && priority.finite? && priority == priority.floor
      priority = 0 unless priority.is_a?(Numeric) && priority.finite?

      {
        values: {
          kind: kind,
          body: body_text,
          sponsor_name: sponsor_name,
          link_url: link_url,
          priority: priority,
          active: input["active"] != false,
          starts_at: starts_at,
          ends_at: ends_at
        }
      }
    end
  end
end
