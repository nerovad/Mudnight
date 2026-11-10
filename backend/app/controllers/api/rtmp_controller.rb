# nginx-rtmp on_publish auth hook (ported from backend/src/controllers/rtmpController.ts).
# nginx sends application/x-www-form-urlencoded: name=<stream_key>&app=live
# Any 2xx allows the publish; anything else rejects it.
class Api::RtmpController < ApplicationController
  include ChannelOwnerAuth

  # POST /api/rtmp/auth
  def auth
    query = request.query_parameters
    key = js_trim(js_string(first_defined(body["name"], query["name"], "")))
    app = js_trim(js_string(first_defined(body["app"], query["app"], "live")))

    return send_text("missing key", 403) if key.empty?

    # Optional: ensure app matches what you expect
    return send_text("invalid app", 403) if !app.empty? && app != "live"

    rows = Db.query("SELECT 1 FROM channels WHERE stream_key = $1 LIMIT 1", [key]).rows
    return send_text("invalid key", 403) if rows.empty?

    send_text("OK", 200)
  rescue StandardError => e
    Rails.logger.error("verifyStreamKey error: #{e.class}: #{e.message}")
    # non-2xx will reject the publish
    send_text("auth error", 500)
  end

  private

  # a ?? b ?? c
  def first_defined(*values)
    values.find { |v| !v.nil? }
  end

  # String(v)
  def js_string(v)
    case v
    when Array then v.map { |x| x.nil? ? "" : js_string(x) }.join(",")
    when Hash then "[object Object]"
    else v.to_s
    end
  end
end
