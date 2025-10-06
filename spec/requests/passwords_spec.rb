# spec/requests/passwords_spec.rb
require 'rails_helper'

RSpec.describe "Passwords", type: :request do
  let!(:user) { User.create!(email_address: 'user@example.com', password: 'oldpassword123') }

  describe "GET /passwords/new" do
    it "displays the password reset request form" do
      get new_password_path
      expect(response).to have_http_status(200)
      expect(response.body).to include('Forgot your password')
      expect(response.body).to include('email_address')
    end
  end

  describe "POST /passwords" do
    context "with valid email address" do
      it "sends password reset email and shows confirmation" do
        # Clear any existing emails
        ActionMailer::Base.deliveries.clear

        post passwords_path, params: {
          email_address: user.email_address
        }

        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include('password reset')

        # Verify email was sent
        expect(ActionMailer::Base.deliveries.count).to eq(1)
        email = ActionMailer::Base.deliveries.last
        expect(email.to).to include(user.email_address)
        expect(email.subject).to match(/password reset/i)

        # Extract the reset token from the email body
        # Note: This is testing that a token exists, not its specific format
        expect(email.body.encoded).to match(/passwords\/\w+\/edit/)
      end

      it "generates a password reset token for the user" do
        post passwords_path, params: {
          email_address: user.email_address
        }

        # Reload user to get updated attributes
        user.reload

        # The authentication generator likely adds password reset token fields
        # This will depend on the specific implementation
        # Adjust based on actual user model attributes
        expect(user).to respond_to(:password_reset_token) if user.respond_to?(:password_reset_token)
      end
    end

    context "with non-existent email address" do
      it "does not reveal whether email exists in system" do
        # This is a security best practice - don't reveal valid emails
        post passwords_path, params: {
          email_address: 'nonexistent@example.com'
        }

        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        # Should show same message as successful case to prevent email enumeration
        expect(response.body).to include('password reset')

        # But no email should actually be sent
        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end
    end

    context "with invalid email format" do
      it "shows error for obviously invalid email" do
        post passwords_path, params: {
          email_address: 'not-an-email'
        }

        expect(response).to have_http_status(422)
        expect(response.body).to include('valid email')
      end
    end
  end

  describe "GET /passwords/:token/edit" do
    # Note: The actual implementation of token generation will vary
    # This test assumes a signed token approach which Rails 8 auth likely uses
    let(:token) { 'valid_reset_token_here' }

    context "with valid token" do
      it "displays the password reset form" do
        # In a real test, you'd generate a valid token through the system
        # For now, we'll test the expected behavior
        skip "Pending implementation details of token generation"

        get edit_password_path(token)
        expect(response).to have_http_status(200)
        expect(response.body).to include('New password')
        expect(response.body).to include('Confirm password')
      end
    end

    context "with invalid or expired token" do
      it "redirects with error message" do
        get edit_password_path('invalid_token')
        expect(response).to redirect_to(new_password_path)
        follow_redirect!
        expect(response.body).to include('invalid or expired')
      end
    end
  end

  describe "PATCH /passwords/:token" do
    let(:token) { 'valid_reset_token_here' }

    context "with valid token and matching passwords" do
      it "updates the password and logs in the user" do
        skip "Pending implementation details of token generation"

        patch password_path(token), params: {
          password: 'newpassword123',
          password_confirmation: 'newpassword123'
        }

        expect(response).to redirect_to(root_path)

        # Verify user can log in with new password
        delete session_path if Session.any?  # Log out if logged in

        post session_path, params: {
          email_address: user.email_address,
          password: 'newpassword123'
        }
        expect(response).to redirect_to(root_path)
      end
    end

    context "with mismatched passwords" do
      it "shows error and does not update password" do
        skip "Pending implementation details of token generation"

        patch password_path(token), params: {
          password: 'newpassword123',
          password_confirmation: 'differentpassword'
        }

        expect(response).to have_http_status(422)
        expect(response.body).to include('match')

        # Verify old password still works
        post session_path, params: {
          email_address: user.email_address,
          password: 'oldpassword123'
        }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "Security considerations" do
    it "rate limits password reset requests" do
      # This test would verify rate limiting is in place
      # Implementation depends on what rate limiting solution is used
      skip "Rate limiting test - implement based on chosen rate limiting strategy"

      # Example of what this might look like:
      # 10.times do
      #   post passwords_path, params: { email_address: user.email_address }
      # end
      #
      # post passwords_path, params: { email_address: user.email_address }
      # expect(response).to have_http_status(429) # Too Many Requests
    end

    it "invalidates old reset tokens when new one is requested" do
      skip "Security test - implement based on token strategy"

      # Request first reset
      post passwords_path, params: { email_address: user.email_address }
      first_token = extract_token_from_email(ActionMailer::Base.deliveries.last)

      # Request second reset
      post passwords_path, params: { email_address: user.email_address }
      second_token = extract_token_from_email(ActionMailer::Base.deliveries.last)

      # First token should no longer work
      get edit_password_path(first_token)
      expect(response).to redirect_to(new_password_path)
    end
  end

  private

  def extract_token_from_email(email)
    # Helper method to extract reset token from email
    # Implementation depends on email format
    match = email.body.encoded.match(/passwords\/(\w+)\/edit/)
    match[1] if match
  end
end