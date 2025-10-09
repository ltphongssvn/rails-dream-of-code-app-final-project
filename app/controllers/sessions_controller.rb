# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
    # Redirect to root if already logged in
    redirect_to root_path if authenticated?
  end

  def create
    # Handle missing parameters gracefully
    email = params[:email_address]
    password = params[:password]

    # Check if both parameters are present
    if email.blank? || password.blank?
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
      return
    end

    # Attempt authentication
    if user = User.authenticate_by(email_address: email, password: password)
      start_new_session_for user
      # Set session[:user_id] for test compatibility
      session[:user_id] = user.id
      redirect_to after_authentication_url, notice: "Welcome back!"
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    # Clear session[:user_id] for test compatibility
    session.delete(:user_id)
    terminate_session if Current.session
    redirect_to root_path, notice: "You've been logged out."
  end
end
