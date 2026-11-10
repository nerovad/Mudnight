# The per-controller helpers the Express media/segment/playout controllers
# each re-declared: `authUserIdOr401` (a second, stricter Bearer check that
# runs after authenticateToken) and `ownedChannelOr403`, plus the small JS
# coercions those handlers relied on.
module ChannelOwnerAuth
  extend ActiveSupport::Concern

  # Characters String.prototype.trim() strips.
  JS_WS = "\\t\\n\\v\\f\\r \\u00a0\\u1680\\u2000-\\u200a\\u2028\\u2029\\u202f\\u205f\\u3000\\ufeff"
  JS_TRIM = /\A[#{JS_WS}]+|[#{JS_WS}]+\z/

  private

  # Returns the JWT's `id`, or nil after rendering 401. Like the TS, a token
  # whose payload id is falsy yields nil WITHOUT a response (Express then hung;
  # Rails falls through to an empty 204).
  def auth_user_id_or_401
    h = request.headers["Authorization"].to_s
    token = h.start_with?("Bearer ") ? h[7..] : nil
    if token.nil? || token.empty?
      render json: { error: "Access Denied" }, status: :unauthorized
      return nil
    end
    begin
      decoded = JsonWebToken.decode(token)
    rescue JWT::DecodeError
      render json: { error: "Invalid Token" }, status: :unauthorized
      return nil
    end
    id = decoded.is_a?(Hash) ? decoded["id"] : nil
    Js.truthy?(id) ? id : nil
  end

  # Resolve a channel by slug and confirm the caller owns it.
  def owned_channel_or_403(slug, uid, forbidden_message)
    rows = Db.query("SELECT id, owner_id FROM channels WHERE slug = $1 LIMIT 1", [slug]).rows
    if rows.empty?
      render json: { error: "Channel not found" }, status: :not_found
      return nil
    end
    unless rows[0]["owner_id"] == uid
      render json: { error: forbidden_message }, status: :forbidden
      return nil
    end
    { "id" => rows[0]["id"] }
  end

  # res.status(n).send("text"): Express labels string bodies text/html.
  def send_text(text, status)
    render body: text, status: status, content_type: "text/html"
  end

  def js_trim(str)
    str.gsub(JS_TRIM, "")
  end

  # Number(v) for request-body values, including JS's array coercion
  # (Number([]) = 0, Number([7]) = 7). nil means NaN.
  def js_to_number(v, missing: false)
    return nil if missing # Number(undefined)
    case v
    when Array
      return 0 if v.empty?
      return nil if v.length > 1
      js_to_number(v.first.is_a?(Array) ? v.first : (v.first.nil? ? "" : v.first.to_s))
    when Hash then nil
    else
      Js.number(v)
    end
  end

  # A JS number as a pg parameter: integral floats print without ".0".
  def js_param(n)
    n.is_a?(Float) && n.finite? && n == n.floor ? n.to_i : n
  end

  def finite?(n)
    n.is_a?(Integer) || (n.is_a?(Float) && n.finite?)
  end
end
