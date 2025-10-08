# app/controllers/registrations_controller.rb
class RegistrationsController < ApplicationController
  # Allow unauthenticated access to registration pages
  # Users need to be able to sign up without being logged in
  # Using the allow_unauthenticated_access class method provided by the Authentication concern
  allow_unauthenticated_access only: [:new, :create]
  
  # GET /registrations/new
  # Displays the signup form for creating a new user account
  def new
    @user = User.new
  end
  
  # POST /registrations
  # Processes the signup form submission and creates a new user account
  def create
    @user = User.new(user_params)
    
    if @user.save
      # User account created successfully
      # Automatically log the new user in using the authentication concern's helper method
      # This creates a session record, sets Current.session, and creates the signed cookie
      start_new_session_for(@user)
      
      # Set session[:user_id] for backward compatibility with tests and any code
      # that expects traditional Rails session behavior
      session[:user_id] = @user.id
      
      # Redirect to the appropriate page with a success message
      # The after_authentication_url method returns where the user was trying to go,
      # or defaults to root_path if they came directly to signup
      redirect_to after_authentication_url, notice: "Welcome to the Time Tracker! Your account has been created successfully."
    else
      # Validation failed - re-render the signup form with error messages
      # The @user object contains the validation errors which will be displayed in the form
      render :new, status: :unprocessable_entity
    end
  end
  
  private
  
  # Strong parameters - whitelist the attributes that can be mass-assigned
  # This security measure prevents users from setting attributes they shouldn't have access to
  def user_params
    params.require(:user).permit(
      :email_address,
      :password,
      :password_confirmation,
      :first_name,
      :last_name,
      :time_zone
    )
  end
end
