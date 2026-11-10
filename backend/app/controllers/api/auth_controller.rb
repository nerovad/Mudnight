# Port of backend/src/routes/authRoutes.ts (inline handlers).
#
# controllers/authController.ts (register/login) is not mounted anywhere in the
# Express app, so only the router's own handlers are ported.
#
# express-validator v7 rules are reproduced by the small validator at the
# bottom of this file so 400 bodies keep the exact `{ errors: [...] }` shape:
#   { type: "field", value, msg, path, location: "body" }
# (`value` is omitted when the field was absent, as JSON.stringify drops
# undefined).
module Api
  class AuthController < ApplicationController
    before_action :authenticate_token!, only: :change_password

    THIRTY_DAYS = 30.days.to_i
    RESET_MESSAGE = "If that email is registered, a temporary password has been sent.".freeze

    # POST /api/auth/register
    def register
      errors = validate(
        ["email", :email, "Enter a valid email"],
        ["username", :not_empty, "Username is required"],
        ["password", [:min_length, 6], "Password must be at least 6 characters long"]
      )
      return render(json: { errors: errors }, status: :bad_request) if errors.any?

      email, username, password = body.values_at("email", "username", "password")
      hashed_password = bcrypt_hash(password)

      result = Db.query(
        "INSERT INTO users (email, username, password) VALUES ($1, $2, $3) RETURNING id, email, username",
        [email, username, hashed_password]
      )

      render json: { message: "User created successfully", user: result.rows[0] }, status: :created
    rescue Db::Error => e
      if e.code == "23505"
        return render(json: { error: "Email already in use" }, status: :bad_request) if e.constraint == "users_email_key"
        return render(json: { error: "Username already taken" }, status: :bad_request) if e.constraint == "users_username_key"
      end
      raise
    end

    # POST /api/auth/login
    def login
      email, username, password = body.values_at("email", "username", "password")

      if Js.falsy?(email) && Js.falsy?(username)
        return render(json: { error: "Email or Username is required" }, status: :bad_request)
      end

      user = Db.one(
        "SELECT * FROM users WHERE email = $1 OR username = $2 LIMIT 1",
        [Js.truthy?(email) ? email : nil, Js.truthy?(username) ? username : nil]
      )
      return render(json: { error: "Invalid credentials" }, status: :bad_request) unless user

      unless bcrypt_compare(password, user["password"])
        return render(json: { error: "Invalid credentials" }, status: :bad_request)
      end

      token = JsonWebToken.encode({ id: user["id"] }, expires_in: THIRTY_DAYS)
      render json: { token: token }
    end

    # POST /api/auth/refresh - Issue a new token if the current one is still valid
    def refresh
      # JS `authHeader.split(' ')[1]` (literal single-space split)
      token = request.authorization&.split(/ /, -1)&.[](1)
      return render(json: { error: "Token required" }, status: :unauthorized) if Js.falsy?(token)

      begin
        decoded = JsonWebToken.decode(token)

        # Verify user still exists
        result = Db.query("SELECT id FROM users WHERE id = $1", [decoded["id"]])
        return render(json: { error: "User not found" }, status: :unauthorized) if result.rows.empty?

        # Issue a fresh 30-day token
        new_token = JsonWebToken.encode({ id: decoded["id"] }, expires_in: THIRTY_DAYS)
        render json: { token: new_token }
      rescue StandardError
        render json: { error: "Invalid or expired token" }, status: :unauthorized
      end
    end

    # POST /api/auth/forgot-password
    def forgot_password
      errors = validate(["email", :email, "Enter a valid email"])
      return render(json: { errors: errors }, status: :bad_request) if errors.any?

      email = body["email"]

      result = Db.query("SELECT id, email FROM users WHERE email = $1 LIMIT 1", [email])

      # Always return success to avoid leaking whether the email exists
      return render(json: { message: RESET_MESSAGE }) if result.rows.empty?

      user = result.rows[0]

      # Generate a random temporary password
      temp_password = SecureRandom.hex(8)
      hashed_password = bcrypt_hash(temp_password)

      # Send email (raises on failure -> 500, like nodemailer's rejected sendMail)
      PasswordResetMailer.temp_password(user["email"], temp_password).deliver_now

      # Only rotate the password once the email is actually on its way, so a
      # send failure can't lock the user out of an account they can still use.
      Db.query("UPDATE users SET password = $1 WHERE id = $2", [hashed_password, user["id"]])

      render json: { message: RESET_MESSAGE }
    end

    # POST /api/auth/change-password (authenticated)
    def change_password
      errors = validate(
        ["currentPassword", :not_empty, "Current password is required"],
        ["newPassword", [:min_length, 6], "New password must be at least 6 characters long"]
      )
      return render(json: { errors: errors }, status: :bad_request) if errors.any?

      current_password, new_password = body.values_at("currentPassword", "newPassword")

      result = Db.query("SELECT password FROM users WHERE id = $1", [current_user_id])
      return render(json: { error: "User not found" }, status: :not_found) if result.rows.empty?

      unless bcrypt_compare(current_password, result.rows[0]["password"])
        return render(json: { error: "Current password is incorrect" }, status: :bad_request)
      end

      hashed_password = bcrypt_hash(new_password)
      Db.query("UPDATE users SET password = $1 WHERE id = $2", [hashed_password, current_user_id])

      render json: { message: "Password updated successfully" }
    end

    private

    # --- node bcrypt semantics ---

    # bcrypt.hash(data, 10): non-string data throws (-> 500 via next(err)).
    def bcrypt_hash(data)
      raise ArgumentError, "data must be a string or Buffer and salt must either be a salt string or a number of rounds" unless data.is_a?(String)

      BCrypt::Password.create(data, cost: 10).to_s
    end

    # bcrypt.compare(data, hash): missing/non-string args throw; an invalid
    # hash string just doesn't match.
    def bcrypt_compare(data, hash)
      raise ArgumentError, "data and hash arguments required" if data.nil? || hash.nil?
      raise ArgumentError, "data must be a string or Buffer and hash must be strings" unless data.is_a?(String) && hash.is_a?(String)

      BCrypt::Password.new(hash) == data
    rescue BCrypt::Errors::InvalidHash
      false
    end

    # --- express-validator v7 (body() chains, one validator each) ---

    # rules: [field, validator, message]; returns errors in chain order.
    def validate(*rules)
      rules.each_with_object([]) do |(field, validator, message), errors|
        present = body.key?(field)
        value = body[field]
        # Standard validators run once per array element (none for []).
        values = value.is_a?(Array) ? value : [value]
        values.each do |item|
          next if run_validator(validator, ev_to_string(item))

          error = { type: "field" }
          error[:value] = item if present
          error.merge!(msg: message, path: field, location: "body")
          errors << error
        end
      end
    end

    def run_validator(validator, str)
      name, arg = Array(validator)
      case name
      when :email then email?(str)
      when :not_empty then !str.empty?
      when :min_length then js_length(str) >= arg
      end
    end

    # express-validator's toString()
    def ev_to_string(value)
      case value
      when nil then ""
      when Hash then "[object Object]"
      when Array then value.map { |v| v.nil? ? "" : ev_to_string(v) }.join(",")
      when Float
        if value.nan? then ""
        elsif value.finite? && value == value.floor && value.abs < 1e21 then value.to_i.to_s
        else value.to_s
        end
      else value.to_s
      end
    end

    def utf16_length(str) = str.encode("UTF-16LE").bytesize / 2

    # validator.isLength: UTF-16 length minus surrogate pairs and VS15/VS16.
    def js_length(str)
      str.each_char.count { |c| c != "\u{FE0E}" && c != "\u{FE0F}" }
    end

    # JS \s
    JS_WS = "\\t\\n\\v\\f\\r \\u{00a0}\\u{1680}\\u{2000}-\\u{200a}\\u{2028}\\u{2029}\\u{202f}\\u{205f}\\u{3000}\\u{feff}".freeze
    EMAIL_USER_UTF8_PART = /\A[a-z\d!\#\$%&'*+\-\/=?^_`{|}~\u{00A1}-\u{D7FF}\u{F900}-\u{FDCF}\u{FDF0}-\u{FFEF}]+\z/i
    QUOTED_EMAIL_USER_UTF8 = /\A([#{JS_WS}\x01-\x08\x0b\x0c\x0e-\x1f\x7f\x21\x23-\x5b\x5d-\x7e\u{00A0}-\u{D7FF}\u{F900}-\u{FDCF}\u{FDF0}-\u{FFEF}]|(\\[\x01-\x09\x0b\x0c\x0d-\x7f\u{00A0}-\u{D7FF}\u{F900}-\u{FDCF}\u{FDF0}-\u{FFEF}]))*\z/i
    FQDN_TLD = /\A([a-z\u{00A1}-\u{00A8}\u{00AA}-\u{D7FF}\u{F900}-\u{FDCF}\u{FDF0}-\u{FFEF}]{2,}|xn[a-z0-9-]{2,})\z/i
    # JS sees astral chars as surrogate pairs, which fall inside U+00A1..U+FFFF.
    FQDN_PART = /\A[a-z_\u{00a1}-\u{ffff}\u{10000}-\u{10FFFF}0-9-]+\z/i

    # validator.isEmail(str) with default options (v13.12).
    def email?(str)
      return false if utf16_length(str) > 254

      parts = str.split("@", -1)
      domain = parts.pop || ""
      user = parts.join("@")

      return false if user.bytesize > 64 || domain.bytesize > 254
      return false unless fqdn?(domain)

      if user[0] == '"'
        user = user[1...-1] || ""
        return QUOTED_EMAIL_USER_UTF8.match?(user)
      end

      user.split(".", -1).then { |ps| ps.empty? ? [""] : ps }.all? { |part| EMAIL_USER_UTF8_PART.match?(part) }
    end

    # validator.isFQDN(str, { require_tld: true, allow_underscores: false })
    def fqdn?(str)
      parts = str.split(".", -1)
      parts = [""] if parts.empty?
      tld = parts.last
      return false if parts.length < 2
      return false unless FQDN_TLD.match?(tld)
      return false if /[#{JS_WS}]/.match?(tld)
      return false if /\A\d+\z/.match?(tld)

      parts.all? do |part|
        next false if utf16_length(part) > 63
        next false unless FQDN_PART.match?(part)
        next false if /[\u{ff01}-\u{ff5e}]/.match?(part)
        next false if /\A-|-\z/.match?(part)
        next false if part.include?("_")

        true
      end
    end
  end
end
