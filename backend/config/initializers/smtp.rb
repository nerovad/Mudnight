# SMTP transport for outgoing mail (password reset), mirroring the nodemailer
# transport in the Express authRoutes.ts:
#
#   host:   SMTP_HOST
#   port:   Number(SMTP_PORT) || 587
#   secure: Number(SMTP_PORT) === 465   (implicit TLS; otherwise STARTTLS when offered)
#   auth:   SMTP_USER / SMTP_PASS
#
# The sender (SMTP_FROM || SMTP_USER) is set in PasswordResetMailer. The
# delivery method itself is left to the environment (:smtp by default, :test
# in the test environment).
# Number(process.env.SMTP_PORT): undefined -> NaN, "" -> 0, junk -> NaN.
smtp_port_str = ENV["SMTP_PORT"]&.strip
smtp_port_raw = if smtp_port_str.nil? then nil
                elsif smtp_port_str.empty? then 0
                else Integer(smtp_port_str, 10, exception: false) || Float(smtp_port_str, exception: false)
                end
smtp_port = smtp_port_raw.nil? || smtp_port_raw.zero? || (smtp_port_raw.is_a?(Float) && smtp_port_raw.nan?) ? 587 : smtp_port_raw
smtp_secure = smtp_port_raw == 465
smtp_user = ENV["SMTP_USER"]

smtp_settings = {
  address: ENV["SMTP_HOST"].presence || "localhost",
  port: smtp_port,
  user_name: smtp_user,
  password: ENV["SMTP_PASS"],
  authentication: (smtp_user.present? ? :plain : nil),
  ssl: smtp_secure,
  tls: smtp_secure,
  enable_starttls_auto: !smtp_secure
}.compact

ActiveSupport.on_load(:action_mailer) do
  self.smtp_settings = smtp_settings
end
