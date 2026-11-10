# Replaces the nodemailer sendMail in authRoutes.ts POST /forgot-password.
# Transport settings live in config/initializers/smtp.rb.
class PasswordResetMailer < ApplicationMailer
  # nodemailer sent exactly the html/text below, with no wrapping layout.
  layout false

  def temp_password(to, temp_password)
    @temp_password = temp_password

    message = mail(
      from: ENV["SMTP_FROM"].presence || ENV["SMTP_USER"],
      to: to,
      subject: "Cinezoo - Temporary Password"
    )
    # A failed send must surface as an error (-> 500), like nodemailer's
    # rejected promise, even where the environment silences delivery errors.
    message.raise_delivery_errors = true
    message
  end
end
