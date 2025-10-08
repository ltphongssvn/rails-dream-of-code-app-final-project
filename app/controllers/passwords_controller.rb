class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  
  def new
  end
  
  def create
    email = params[:password]&.[](:email_address) || params[:email_address]
    
    unless email&.match?(/\A[^@\s]+@[^@\s]+\z/)
      flash.now[:alert] = "Please enter a valid email address"
      return render :new, status: :unprocessable_entity
    end
    
    if user = User.find_by(email_address: email)
      user.generate_password_reset_token!
      PasswordsMailer.reset(user).deliver_now
    end
    
    redirect_to new_session_path, notice: "Password reset instructions sent (if user with that email address exists)."
  end
  
  def edit
  end
  
  def update
    if params[:password][:password] != params[:password][:password_confirmation]
      flash.now[:alert] = "Passwords do not match"
      return render :edit, status: :unprocessable_entity
    end
    
    if @user.update(password_params)
      start_new_session_for(@user)
      redirect_to root_path, notice: "Password has been reset."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_user_by_token
    @user = User.find_by_password_reset_token!(params[:token])
  rescue ActiveRecord::RecordNotFound, ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
  end
  
  def password_params
    params.require(:password).permit(:password, :password_confirmation)
  end
end
