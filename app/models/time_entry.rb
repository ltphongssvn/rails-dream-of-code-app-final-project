# app/models/time_entry.rb
class TimeEntry < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :category
  
  # Validations that mirror and extend database constraints
  validates :date, presence: true
  validates :hour, presence: true, 
            numericality: { 
              greater_than_or_equal_to: 0, 
              less_than_or_equal_to: 23,
              message: "must be between 0 (midnight) and 23 (11 PM)"
            }
  validates :duration_minutes, presence: true,
            numericality: {
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 60,
              message: "must be between 1 and 60 minutes"
            }
  
  # Ensure no duplicate entries for the same time slot
  validates :hour, uniqueness: { 
    scope: [:user_id, :date], 
    message: "already has an entry for this time slot" 
  }
  
  # Custom validation to prevent future entries (matches database constraint)
  validate :date_cannot_be_in_future
  
  # Scopes for common queries
  scope :for_date, ->(date) { where(date: date) }
  scope :for_hour, ->(hour) { where(hour: hour) }
  scope :for_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :recent, -> { order(date: :desc, hour: :desc) }
  scope :chronological, -> { order(date: :asc, hour: :asc) }
  
  # Class methods for analysis
  def self.hours_by_category(user, start_date, end_date)
    # Returns total minutes spent on each category in the date range
    where(user: user, date: start_date..end_date)
      .group(:category_id)
      .sum(:duration_minutes)
  end
  
  def self.daily_summary(user, date)
    # Returns all entries for a specific day, ordered by hour
    where(user: user, date: date)
      .includes(:category)
      .order(:hour)
  end
  
  # Instance methods
  def time_slot
    # Returns a human-readable time slot like "9:00 AM - 10:00 AM"
    start_time = Time.zone.parse("#{date} #{hour}:00")
    end_time = start_time + 1.hour
    "#{start_time.strftime('%-l:%M %p')} - #{end_time.strftime('%-l:%M %p')}"
  end
  
  def percentage_of_hour
    # Returns how much of the hour was used (e.g., 75 for 45 minutes)
    (duration_minutes / 60.0 * 100).round
  end
  
  def previous_day_entry
    # Finds what the user did at this same hour yesterday
    self.class.find_by(
      user: user,
      date: date - 1.day,
      hour: hour
    )
  end
  
  def previous_week_entry
    # Finds what the user did at this same hour last week
    self.class.find_by(
      user: user,
      date: date - 1.week,
      hour: hour
    )
  end
  
  def similar_entries(days_back: 30)
    # Finds all entries at this same hour in the past N days
    self.class.where(
      user: user,
      hour: hour,
      date: (date - days_back.days)...date
    ).includes(:category).order(date: :desc)
  end
  
  private
  
  def date_cannot_be_in_future
    if date.present? && date > Date.current
      errors.add(:date, "can't be in the future")
    end
  end
end