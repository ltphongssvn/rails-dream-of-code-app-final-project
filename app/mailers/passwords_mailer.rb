class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    @token = user.password_reset_token
    mail subject: "Reset your password", to: user.email_address
  end
end
