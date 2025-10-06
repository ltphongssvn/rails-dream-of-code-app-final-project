# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'requires an email address' do
      user = User.new(password: 'password123')
      expect(user).not_to be_valid
      expect(user.errors[:email_address]).to include("can't be blank")
    end

    it 'requires a unique email address' do
      User.create!(email_address: 'test@example.com', password: 'password123')
      duplicate_user = User.new(email_address: 'test@example.com', password: 'password123')
      expect(duplicate_user).not_to be_valid
      expect(duplicate_user.errors[:email_address]).to include('has already been taken')
    end

    it 'requires a password' do
      user = User.new(email_address: 'test@example.com')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end
  end

  describe 'authentication' do
    let(:user) { User.create!(email_address: 'test@example.com', password: 'password123') }

    it 'authenticates with correct password' do
      expect(user.authenticate('password123')).to eq(user)
    end

    it 'does not authenticate with incorrect password' do
      expect(user.authenticate('wrongpassword')).to be_falsey
    end
  end

  describe 'associations' do
    it { should have_many(:sessions) }
  end
end