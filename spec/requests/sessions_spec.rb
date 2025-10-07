# spec/requests/sessions_spec.rb
require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  let!(:user) {
    User.create!(
      email_address: 'user@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User',
      time_zone: 'Pacific Time (US & Canada)'
    )
  }

  describe "GET /session/new" do
    it "displays the login form" do
      get new_session_path
      expect(response).to have_http_status(200)
      expect(response.body).to include('Sign in')
      expect(response.body).to include('email_address')
      expect(response.body).to include('password')
    end

    it "redirects to root if already logged in" do
      # First, log in the user
      post session_path, params: { email_address: user.email_address, password: 'password123' }

      # Try to access login page while logged in
      get new_session_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /session" do
    context "with valid credentials" do
      it "logs in the user and redirects to root" do
        post session_path, params: {
          email_address: user.email_address,
          password: 'password123'
        }

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('Welcome back')

        # Verify session was created
        expect(session[:user_id]).to eq(user.id)
      end

      it "records IP address and user agent in session" do
        post session_path, params: {
          email_address: user.email_address,
          password: 'password123'
        },
        headers: {
          'REMOTE_ADDR' => '127.0.0.1',
          'HTTP_USER_AGENT' => 'RSpec Test Browser'
        }

        expect(response).to redirect_to(root_path)
        session_record = Session.last
        expect(session_record.user).to eq(user)
        expect(session_record.ip_address).to eq('127.0.0.1')
        expect(session_record.user_agent).to eq('RSpec Test Browser')
      end
    end

    context "with invalid credentials" do
      it "does not log in with wrong password" do
        post session_path, params: {
          email_address: user.email_address,
          password: 'wrongpassword'
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Invalid email or password')
        expect(session[:user_id]).to be_nil
      end

      it "does not log in with non-existent email" do
        post session_path, params: {
          email_address: 'nonexistent@example.com',
          password: 'password123'
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Invalid email or password')
        expect(session[:user_id]).to be_nil
      end

      it "handles missing parameters gracefully" do
        post session_path, params: {}

        expect(response).to have_http_status(:unprocessable_entity)
        expect(session[:user_id]).to be_nil
      end
    end
  end

  describe "DELETE /session" do
    context "when logged in" do
      before do
        post session_path, params: {
          email_address: user.email_address,
          password: 'password123'
        }
      end

      it "logs out the user and destroys the session" do
        expect(session[:user_id]).to eq(user.id)

        delete session_path

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('logged out')
        expect(session[:user_id]).to be_nil
      end
    end

    context "when not logged in" do
      it "redirects to login page" do
        delete session_path
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "Authentication flow integration" do
    it "completes full authentication cycle" do
      # Visit login page
      get new_session_path
      expect(response).to have_http_status(200)

      # Log in
      post session_path, params: {
        email_address: user.email_address,
        password: 'password123'
      }
      expect(response).to redirect_to(root_path)

      # Access protected resource (should work)
      get time_entries_path
      expect(response).to have_http_status(200)

      # Log out
      delete session_path
      expect(response).to redirect_to(root_path)

      # Try to access protected resource (should redirect to login)
      get time_entries_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end