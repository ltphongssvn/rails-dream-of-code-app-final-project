# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  # Define valid attributes that satisfy all validations
  let(:valid_attributes) do
    {
      email_address: 'test@example.com',
      password: 'password123',
      first_name: 'John',
      last_name: 'Doe',
      time_zone: 'Pacific Time (US & Canada)'
    }
  end

  describe 'validations' do
    it 'requires an email address' do
      user = User.new(valid_attributes.except(:email_address))
      expect(user).not_to be_valid
      expect(user.errors[:email_address]).to include("can't be blank")
    end

    it 'requires a unique email address' do
      User.create!(valid_attributes)
      duplicate_user = User.new(valid_attributes)
      expect(duplicate_user).not_to be_valid
      expect(duplicate_user.errors[:email_address]).to include('has already been taken')
    end

    it 'requires a password' do
      user = User.new(valid_attributes.except(:password))
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end

    it 'requires a first name' do
      user = User.new(valid_attributes.except(:first_name))
      expect(user).not_to be_valid
      expect(user.errors[:first_name]).to include("can't be blank")
    end

    it 'validates first name length' do
      user = User.new(valid_attributes.merge(first_name: 'a' * 101))
      expect(user).not_to be_valid
      expect(user.errors[:first_name]).to include('is too long (maximum is 100 characters)')
    end

    it 'requires a last name' do
      user = User.new(valid_attributes.except(:last_name))
      expect(user).not_to be_valid
      expect(user.errors[:last_name]).to include("can't be blank")
    end

    it 'validates last name length' do
      user = User.new(valid_attributes.merge(last_name: 'a' * 101))
      expect(user).not_to be_valid
      expect(user.errors[:last_name]).to include('is too long (maximum is 100 characters)')
    end

    it 'requires a time zone' do
      user = User.new(valid_attributes.merge(time_zone: ''))
      expect(user).not_to be_valid
      expect(user.errors[:time_zone]).to include("can't be blank")
    end
  end

  describe 'authentication' do
    let(:user) { User.create!(valid_attributes) }

    it 'authenticates with correct password' do
      expect(user.authenticate('password123')).to eq(user)
    end

    it 'does not authenticate with incorrect password' do
      expect(user.authenticate('wrongpassword')).to be_falsey
    end
  end

  describe 'associations' do
    it { should have_many(:sessions) }
    it { should have_many(:categories) }
    it { should have_many(:time_entries) }
    it { should have_many(:goals) }
  end
end