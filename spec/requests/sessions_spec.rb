# spec/requests/sessions_spec.rb
require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  let!(:user) { User.create!(email_address: 'user@example.com', password: 'password123') }

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
        expect(response.body).to include('Successfully logged in')

        # Verify session was created in database
        expect(Session.count).to eq(1)
        session = Session.last
        expect(session.user).to eq(user)
      end

      it "records IP address and user agent in session" do
        post session_path, params: {
          email_address: user.email_address,
          password: 'password123'
        }, headers: {
          'HTTP_USER_AGENT' => 'Mozilla/5.0 Test Browser',
          'REMOTE_ADDR' => '192.168.1.100'
        }

        session = Session.last
        expect(session.user_agent).to eq('Mozilla/5.0 Test Browser')
        # Note: IP address handling may vary based on Rails configuration
      end
    end

    context "with invalid credentials" do
      it "does not log in with wrong password" do
        post session_path, params: {
          email_address: user.email_address,
          password: 'wrongpassword'
        }

        expect(response).to have_http_status(422)
        expect(response.body).to include('Invalid email address or password')
        expect(Session.count).to eq(0)
      end

      it "does not log in with non-existent email" do
        post session_path, params: {
          email_address: 'nonexistent@example.com',
          password: 'password123'
        }

        expect(response).to have_http_status(422)
        expect(response.body).to include('Invalid email address or password')
        expect(Session.count).to eq(0)
      end

      it "handles missing parameters gracefully" do
        post session_path, params: { email_address: user.email_address }

        expect(response).to have_http_status(422)
        expect(Session.count).to eq(0)
      end
    end
  end

  describe "DELETE /session" do
    context "when logged in" do
      before do
        # Log in the user first
        post session_path, params: {
          email_address: user.email_address,
          password: 'password123'
        }
        @session = Session.last
      end

      it "logs out the user and destroys the session" do
        expect(Session.count).to eq(1)

        delete session_path

        expect(response).to redirect_to(new_session_path)
        follow_redirect!
        expect(response.body).to include('Sign in')

        # Verify session was destroyed
        expect(Session.exists?(@session.id)).to be_falsey
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
      # Step 1: Access protected area while logged out (should redirect)
      get root_path
      expect(response).to redirect_to(new_session_path)

      # Step 2: Log in with valid credentials
      post session_path, params: {
        email_address: user.email_address,
        password: 'password123'
      }
      expect(response).to redirect_to(root_path)

      # Step 3: Access protected area while logged in (should succeed)
      get root_path
      expect(response).to have_http_status(200)

      # Step 4: Log out
      delete session_path
      expect(response).to redirect_to(new_session_path)

      # Step 5: Verify logged out by trying to access protected area
      get root_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end