# HS256 JWTs signed with JWT_SECRET, interchangeable with tokens issued by the
# old Express backend (jsonwebtoken), so existing sessions stay valid.
module JsonWebToken
  module_function

  def secret
    ENV.fetch("JWT_SECRET")
  end

  # expires_in: seconds (jsonwebtoken's `expiresIn`), or nil for no expiry.
  def encode(payload, expires_in: nil)
    claims = payload.transform_keys(&:to_s).merge("iat" => Time.now.to_i)
    claims["exp"] = Time.now.to_i + expires_in.to_i if expires_in
    JWT.encode(claims, secret, "HS256")
  end

  # Raises JWT::DecodeError (incl. JWT::ExpiredSignature) when invalid.
  def decode(token)
    JWT.decode(token, secret, true, algorithms: %w[HS256 HS384 HS512]).first
  end
end
