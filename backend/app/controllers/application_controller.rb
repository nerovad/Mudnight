# Base for every /api controller.
#
# Mirrors the Express middleware stack:
#   authenticateToken  -> before_action :authenticate_token!
#   requireGroup(...)  -> before_action -> { require_group!("super_admin") }
#   errorHandler       -> rescue_from StandardError (500 {"error": "Internal Server Error"})
#
# Handlers read the JSON body through `body` (string keys, like req.body) and
# render rows straight from `Db.query`.
class ApplicationController < ActionController::API
  USER_GROUPS = %w[super_admin network general_user].freeze

  # Express never wrapped JSON bodies under a resource key.
  wrap_parameters false

  rescue_from StandardError do |error|
    Rails.logger.error("[ERROR] #{request.method} #{request.path}: #{error.message}\n#{error.backtrace&.first(15)&.join("\n")}")
    render json: { error: "Internal Server Error" }, status: :internal_server_error
  end

  attr_reader :current_user_id, :current_user_group

  private

  # req.body: the parsed JSON/form body as a plain string-keyed Hash.
  def body
    @body ||= request.request_parameters.to_h
  end

  # Verifies `Authorization: Bearer <jwt>` and loads the user's group.
  def authenticate_token!
    token = request.authorization.to_s.split(/ /)[1]
    return render(json: { error: "Access token required" }, status: :unauthorized) if token.blank?

    payload = JsonWebToken.decode(token)
    @current_user_id = payload["id"]
    @current_user_group = Db.one("SELECT user_group FROM users WHERE id = $1", [@current_user_id])&.dig("user_group")
  rescue JWT::DecodeError
    render json: { error: "Invalid or expired token" }, status: :unauthorized
  end

  def require_group!(*groups)
    return if current_user_group && groups.map(&:to_s).include?(current_user_group)

    render json: { error: "Insufficient permissions" }, status: :forbidden
  end

  # Like authenticate_token!, but never rejects: sets current_user_id when a
  # valid token is present (for handlers that peek at an optional token).
  def optional_user_id
    token = request.authorization.to_s.split(/ /)[1]
    return nil if token.blank?

    JsonWebToken.decode(token)["id"]
  rescue JWT::DecodeError
    nil
  end
end
