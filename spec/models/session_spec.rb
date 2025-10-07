# spec/models/session_spec.rb
require 'rails_helper'

RSpec.describe Session, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    let(:user) {
      User.create!(
        email_address: 'test@example.com',
        password: 'password123',
        first_name: 'Jane',
        last_name: 'Smith',
        time_zone: 'Eastern Time (US & Canada)'
      )
    }

    it 'requires a user' do
      session = Session.new(ip_address: '127.0.0.1', user_agent: 'Mozilla/5.0')
      expect(session).not_to be_valid
      expect(session.errors[:user]).to include('must exist')
    end

    it 'can be created with valid attributes' do
      session = Session.new(
        user: user,
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      )
      expect(session).to be_valid
    end

    it 'stores IP address' do
      session = Session.create!(
        user: user,
        ip_address: '10.0.0.1',
        user_agent: 'Test Browser'
      )
      expect(session.ip_address).to eq('10.0.0.1')
    end

    it 'stores user agent information' do
      user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
      session = Session.create!(
        user: user,
        ip_address: '127.0.0.1',
        user_agent: user_agent
      )
      expect(session.user_agent).to eq(user_agent)
    end
  end

  describe 'session management' do
    let(:user) {
      User.create!(
        email_address: 'manager@example.com',
        password: 'password123',
        first_name: 'Bob',
        last_name: 'Manager',
        time_zone: 'Central Time (US & Canada)'
      )
    }

    it 'allows multiple sessions for the same user' do
      session1 = Session.create!(user: user, ip_address: '192.168.1.1', user_agent: 'Chrome')
      session2 = Session.create!(user: user, ip_address: '192.168.1.2', user_agent: 'Firefox')

      expect(user.sessions.count).to eq(2)
      expect(user.sessions).to include(session1, session2)
    end
  end
end