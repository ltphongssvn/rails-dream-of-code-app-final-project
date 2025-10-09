class User < ApplicationRecord
  has_secure_password
  
  # Associations
  has_many :sessions, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :time_entries, dependent: :destroy

  has_many :goals, dependent: :destroy
  
  # Validations
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }
  validates :first_name, presence: true, length: { maximum: 100 }
  validates :last_name, presence: true, length: { maximum: 100 }
  validates :time_zone, presence: true
  
  # Normalize email before saving
  normalizes :email_address, with: -> e { e.strip.downcase }

  # Password reset functionality
  def generate_password_reset_token!
    self.password_reset_token = generate_token_for(:password_reset)
    self.password_reset_sent_at = Time.current
    save!(validate: false)
    password_reset_token
  end

  def self.find_by_password_reset_token!(token)
    user = find_by_token_for(:password_reset, token)
    raise ActiveRecord::RecordNotFound unless user
    user
  end

  def time_entries_for_date(date)
    time_entries.where(date: date).includes(:category)
  end

  def active_goals_for_day(date)
    goals.active.where("days_of_week LIKE ?", "%#{date.strftime('%A')}%")
  end

  private

  def generate_token_for(purpose)
    Rails.application.message_verifier(purpose.to_s).generate([id, Time.current.to_i], purpose: "User\n#{purpose}\n900", expires_in: 15.minutes)
  end

  def self.find_by_token_for(purpose, token)
    payload = Rails.application.message_verifier(purpose.to_s).verify(token, purpose: "User\n#{purpose}\n900")
    find_by(id: payload[0]) if payload
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end
end
