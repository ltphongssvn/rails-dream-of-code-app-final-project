# app/models/user.rb
class User < ApplicationRecord
  has_secure_password
  
  # Authentication associations
  has_many :sessions, dependent: :destroy
  
  # Time tracking associations
  has_many :categories, dependent: :destroy
  has_many :time_entries, dependent: :destroy
  has_many :goals, dependent: :destroy
  
  # Indirect association to goal completions through goals
  has_many :goal_completions, through: :goals
  
  # Email normalization - ensures consistency
  normalizes :email_address, with: ->(e) { e.strip.downcase }
  
  # Validations
  validates :email_address, 
    presence: true, 
    uniqueness: { case_sensitive: false },
    format: { 
      with: URI::MailTo::EMAIL_REGEXP,
      message: "must be a valid email address" 
    }
  
  validates :first_name, presence: true, length: { maximum: 100 }
  validates :last_name, presence: true, length: { maximum: 100 }
  
  validates :time_zone, 
    presence: true,
    inclusion: { 
      in: ActiveSupport::TimeZone.all.map(&:name),
      message: "must be a valid time zone" 
    }
  
  # Callbacks
  before_validation :set_default_time_zone, on: :create
  
  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end
  
  def display_name
    full_name.presence || email_address
  end
  
  # Returns time entries for a specific date
  def time_entries_for_date(date)
    time_entries.where(date: date).includes(:category)
  end
  
  # Returns goals active on a specific day of the week
  def active_goals_for_day(date = Date.current)
    day_name = date.strftime('%A')
    goals.active.where("days_of_week LIKE ?", "%#{day_name}%")
  end
  
  # Calculate total minutes tracked for a specific date
  def total_minutes_for_date(date)
    time_entries_for_date(date).sum(:duration_minutes)
  end
  
  # Check if user has any data (to prevent accidental deletion)
  def has_tracking_data?
    time_entries.exists? || goals.exists? || categories.exists?
  end
  
  private
  
  def set_default_time_zone
    self.time_zone ||= 'Pacific Time (US & Canada)'
  end
end