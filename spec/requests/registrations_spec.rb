# spec/requests/registrations_spec.rb
require 'rails_helper'

RSpec.describe "Registrations", type: :request do
  describe "GET /registrations/new" do
    it "displays the signup form" do
      get new_registration_path
      expect(response).to have_http_status(200)
      expect(response.body).to include('Create Your Account')
      expect(response.body).to include('email_address')
      expect(response.body).to include('password')
      expect(response.body).to include('password_confirmation')
      expect(response.body).to include('first_name')
      expect(response.body).to include('last_name')
      expect(response.body).to include('time_zone')
    end

    it "allows unauthenticated access to the signup form" do
      # This test verifies that visitors who aren't logged in
      # can access the registration page without being redirected to login
      get new_registration_path
      expect(response).to have_http_status(200)
      expect(response).not_to redirect_to(new_session_path)
    end
  end

  describe "POST /registrations" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          user: {
            email_address: 'newuser@example.com',
            password: 'securepassword123',
            password_confirmation: 'securepassword123',
            first_name: 'New',
            last_name: 'User',
            time_zone: 'Pacific Time (US & Canada)'
          }
        }
      end

      it "creates a new user account" do
        expect {
          post registrations_path, params: valid_params
        }.to change(User, :count).by(1)

        new_user = User.last
        expect(new_user.email_address).to eq('newuser@example.com')
        expect(new_user.first_name).to eq('New')
        expect(new_user.last_name).to eq('User')
        expect(new_user.time_zone).to eq('Pacific Time (US & Canada)')
      end

      it "encrypts the password securely" do
        post registrations_path, params: valid_params

        new_user = User.last
        # Password should be encrypted, not stored in plain text
        expect(new_user.password_digest).to be_present
        expect(new_user.password_digest).not_to eq('securepassword123')
        # But the user should be able to authenticate with the original password
        expect(new_user.authenticate('securepassword123')).to eq(new_user)
      end

      it "automatically logs in the new user" do
        post registrations_path, params: valid_params

        # Verify that a session was created for the new user
        new_user = User.last
        session_record = Session.find_by(user: new_user)
        expect(session_record).to be_present
        expect(session_record.user).to eq(new_user)
      end

      it "records IP address and user agent in the session" do
        post registrations_path,
             params: valid_params,
             headers: {
               'REMOTE_ADDR' => '192.168.1.1',
               'HTTP_USER_AGENT' => 'Test Browser'
             }

        new_user = User.last
        session_record = Session.find_by(user: new_user)
        expect(session_record.ip_address).to eq('192.168.1.1')
        expect(session_record.user_agent).to eq('Test Browser')
      end

      it "redirects to the root path with a welcome message" do
        post registrations_path, params: valid_params

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('Welcome to the Time Tracker')
        expect(response.body).to include('account has been created successfully')
      end
    end

    context "with invalid parameters" do
      it "does not create a user with duplicate email address" do
        # Create an existing user with this email
        User.create!(
          email_address: 'existing@example.com',
          password: 'password123',
          first_name: 'Existing',
          last_name: 'User',
          time_zone: 'Pacific Time (US & Canada)'
        )

        # Attempt to create another user with the same email
        expect {
          post registrations_path, params: {
            user: {
              email_address: 'existing@example.com',
              password: 'newpassword123',
              password_confirmation: 'newpassword123',
              first_name: 'Duplicate',
              last_name: 'User',
              time_zone: 'Pacific Time (US & Canada)'
            }
          }
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Email address has already been taken')
      end

      it "does not create a user with mismatched password confirmation" do
        expect {
          post registrations_path, params: {
            user: {
              email_address: 'newuser@example.com',
              password: 'password123',
              password_confirmation: 'different_password',
              first_name: 'New',
              last_name: 'User',
              time_zone: 'Pacific Time (US & Canada)'
            }
          }
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Password confirmation')
      end

      it "does not create a user with missing required fields" do
        expect {
          post registrations_path, params: {
            user: {
              email_address: 'incomplete@example.com',
              password: 'password123',
              password_confirmation: 'password123'
              # Missing first_name, last_name, time_zone
            }
          }
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('First name')
        expect(response.body).to include('Last name')
      end

      it "does not create a user with invalid email format" do
        expect {
          post registrations_path, params: {
            user: {
              email_address: 'not-an-email',
              password: 'password123',
              password_confirmation: 'password123',
              first_name: 'New',
              last_name: 'User',
              time_zone: 'Pacific Time (US & Canada)'
            }
          }
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Email address')
      end

      it "re-renders the signup form with validation errors" do
        post registrations_path, params: {
          user: {
            email_address: 'invalid',
            password: 'pass',
            password_confirmation: 'different',
            first_name: '',
            last_name: ''
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Create Your Account')
        expect(response.body).to include('error')
      end
    end
  end

  describe "Registration integration" do
    it "completes full signup and authentication flow" do
      # Visit the signup page
      get new_registration_path
      expect(response).to have_http_status(200)

      # Submit valid registration data
      post registrations_path, params: {
        user: {
          email_address: 'integrated@example.com',
          password: 'testpassword123',
          password_confirmation: 'testpassword123',
          first_name: 'Integration',
          last_name: 'Test',
          time_zone: 'Pacific Time (US & Canada)'
        }
      }

      # Should redirect after successful signup
      expect(response).to redirect_to(root_path)

      # Follow the redirect to complete the signup flow
      # This is critical for properly establishing session state in tests
      follow_redirect!
      expect(response).to have_http_status(200)

      # Should be able to access protected resources immediately without logging in again
      get time_entries_path
      expect(response).to have_http_status(200)
      expect(response).not_to redirect_to(new_session_path)

      # Verify the user can access their goals
      get goals_path
      expect(response).to have_http_status(200)

      # Verify the user can create categories
      get new_category_path
      expect(response).to have_http_status(200)
    end
  end
end