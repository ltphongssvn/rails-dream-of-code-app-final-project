# spec/requests/passwords_spec.rb
require 'rails_helper'

RSpec.describe "Passwords", type: :request do
  let!(:user) {
    User.create!(
      email_address: 'user@example.com',
      password: 'oldpassword123',
      first_name: 'Test',
      last_name: 'User',
      time_zone: 'Pacific Time (US & Canada)'
    )
  }

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
        ActionMailer::Base.deliveries.clear

        post passwords_path, params: {
          password: { email_address: user.email_address }
        }

        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include('Password reset instructions sent')

        expect(ActionMailer::Base.deliveries.count).to eq(1)
        email = ActionMailer::Base.deliveries.last
        expect(email.to).to include(user.email_address)
        expect(email.subject).to match(/reset.*password/i)
      end

      xit "generates a password reset token for the user" do
        user.update!(password_reset_token: nil, password_reset_sent_at: nil)
        expect(user.password_reset_token).to be_nil

        post passwords_path, params: {
          password: { email_address: user.email_address }
        }

        user.reload
        expect(user.password_reset_token).to be_present
        expect(user.password_reset_sent_at).to be_present
        expect(user.password_reset_sent_at).to be_within(2.seconds).of(Time.current)
      end
    end

    context "with non-existent email address" do
      it "does not reveal whether email exists in system" do
        post passwords_path, params: {
          password: { email_address: 'nonexistent@example.com' }
        }

        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include('Password reset instructions sent')

        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end
    end

    context "with invalid email format" do
      it "shows error for obviously invalid email" do
        post passwords_path, params: {
          password: { email_address: 'not-an-email' }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('valid email')
      end
    end
  end

  describe "GET /passwords/:token/edit" do
    context "with valid token" do
      let(:token) { user.generate_password_reset_token! }
      
      before do
        user.update!(password_reset_sent_at: 1.hour.ago)
      end

      xit "displays the password reset form" do
        get edit_password_path(token)

        expect(response).to have_http_status(200)
        expect(response.body).to include('Reset your password')
        expect(response.body).to include('New password')
        expect(response.body).to include('Confirm password')
      end
    end

    context "with invalid or expired token" do
      it "redirects with error message" do
        get edit_password_path('invalid_token')

        expect(response).to redirect_to(new_password_path)
        follow_redirect!
        expect(response.body).to include('Password reset link is invalid or has expired')
      end
    end
  end

  describe "PATCH /passwords/:token" do
    let(:token) { user.generate_password_reset_token! }
    
    before do
      user.update!(password_reset_sent_at: 1.hour.ago)
    end

    context "with valid token and matching passwords" do
      xit "updates the password and logs in the user" do
        patch password_path(token), params: {
          password: {
            password: 'newpassword123',
            password_confirmation: 'newpassword123'
          }
        }

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('Password successfully reset')

        expect(session[:user_id]).to eq(user.id)

        user.reload
        expect(user.authenticate('oldpassword123')).to be_falsey
        expect(user.authenticate('newpassword123')).to be_truthy
      end
    end

    context "with mismatched passwords" do
      xit "shows error and does not update password" do
        patch password_path(token), params: {
          password: {
            password: 'newpassword123',
            password_confirmation: 'differentpassword'
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Passwords do not match')

        user.reload
        expect(user.authenticate('oldpassword123')).to be_truthy
      end
    end
  end

  describe "Security considerations" do
    xit "rate limits password reset requests" do
      5.times do
        post passwords_path, params: {
          password: { email_address: user.email_address }
        }
      end

      post passwords_path, params: {
        password: { email_address: user.email_address }
      }

      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect(response.body).to include('too many password reset attempts')
    end

    it "invalidates old reset tokens when new one is requested" do
      post passwords_path, params: {
        password: { email_address: user.email_address }
      }
      user.reload
      first_token = user.password_reset_token

      post passwords_path, params: {
        password: { email_address: user.email_address }
      }
      user.reload
      second_token = user.password_reset_token

      expect(second_token).not_to eq(first_token)

      patch password_path(first_token), params: {
        password: {
          password: 'newpassword123',
          password_confirmation: 'newpassword123'
        }
      }

      expect(response).to redirect_to(new_password_path)
    end
  end
end
