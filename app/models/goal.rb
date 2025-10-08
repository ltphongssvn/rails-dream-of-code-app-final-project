# app/models/goal.rb
class Goal < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :category, optional: true  # Goals can be category-specific or general
  has_many :goal_completions, dependent: :destroy

  # Scopes for filtering
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :daily, -> { where(goal_type: 'daily') }
  scope :weekly, -> { where(goal_type: 'weekly') }
  scope :specific_hour, -> { where(goal_type: 'specific_hour') }

  # Additional scopes the tests expect
  scope :by_type, ->(type) { where(goal_type: type) }

  # This scope needs to match exact day, not partial match
  scope :for_day_of_week, ->(day) {
    where("days_of_week LIKE ? OR days_of_week LIKE ? OR days_of_week LIKE ? OR days_of_week = ?",
          "%[\"#{day}\"%",     # Matches ["Monday"] or ["Monday","Tuesday"]
          "%,\"#{day}\"%",     # Matches ["Sunday","Monday"]
          "%\"#{day}\"]%",     # Matches ["Monday"] at the end
          "[\"#{day}\"]")      # Matches exactly ["Monday"]
  }

  # Constants for goal types
  GOAL_TYPES = ['daily', 'weekly', 'specific_hour'].freeze
  DAYS_OF_WEEK = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].freeze

  # Validations
  validates :user, presence: true
  validates :goal_type, presence: true, inclusion: { in: GOAL_TYPES }
  validates :target_minutes, presence: true,
    numericality: { greater_than: 0, less_than_or_equal_to: 1440 }

  # Custom message for hour validation to match test expectations
  validates :hour, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 23,
    message: "must be between 0 and 23",
    allow_nil: true
  }

  validate :hour_required_for_specific_hour_goals
  validate :hour_not_allowed_for_other_goals
  validate :days_of_week_format

  # Callbacks
  before_validation :set_defaults
  before_save :serialize_days_of_week

  # Public getter for days_array - always parses fresh from days_of_week
  def days_array
    return [] if days_of_week.blank?

    begin
      parsed = JSON.parse(days_of_week)
      parsed.is_a?(Array) ? parsed : []
    rescue JSON::ParserError
      []
    end
  end

  # Public setter for days_array
  def days_array=(value)
    # Directly update days_of_week when days_array is set
    if value.nil? || value.empty?
      self.days_of_week = '[]'
    else
      self.days_of_week = value.to_json
    end
  end

  # Check if goal applies to a specific date
  def applies_to_date?(date)
    return false unless active?

    day_name = date.strftime('%A')
    days_list = days_array

    # If no specific days set or empty array, goal applies to all days
    return true if days_list.empty? || days_list == []

    # Check if the specific day is in the list
    days_list.include?(day_name)
  end

  # Alias for compatibility with different naming conventions
  def applies_on_date?(date)
    applies_to_date?(date)
  end

  # Check if goal was completed for a specific date
  def completed_on?(date)
    goal_completions.where(date: date, achieved: true).exists?
  end

  # Check if goal was achieved on a specific date
  def achieved_on_date?(date)
    completion = goal_completions.find_by(date: date)
    completion&.achieved? || false
  end

  # Get completion record for a date (don't auto-create)
  def completion_for_date(date)
    goal_completions.find_by(date: date)
  end

  # Calculate completion percentage for a date range
  def completion_percentage(start_date, end_date)
    applicable_dates = (start_date..end_date).select { |date| applies_to_date?(date) }
    return 0 if applicable_dates.empty?

    completed_count = goal_completions
      .where(date: applicable_dates, achieved: true)
      .count

    (completed_count.to_f / applicable_dates.size * 100).round(1)
  end

  # Calculate overall completion rate
  def completion_rate
    return 0 if goal_completions.empty?

    achieved_count = goal_completions.where(achieved: true).count
    total_count = goal_completions.count

    return 0 if total_count == 0
    ((achieved_count.to_f / total_count) * 100).round
  end

  # Calculate current streak of consecutive achievements
  def current_streak
    return 0 if goal_completions.empty?
    
    recent_completions = goal_completions.order(date: :desc)
    return 0 unless recent_completions.first&.achieved?
    
    streak = 0
    current_date = recent_completions.first.date
    
    # Count consecutive achieved days backwards from most recent
    recent_completions.each do |completion|
      break if completion.date != current_date
      break unless completion.achieved?
      
      streak += 1
      current_date -= 1.day
    end
    
    streak
  end

  # Check and record completion based on actual time tracked
  def check_and_record_completion(date)
    # Find or initialize a completion record for this date
    completion = goal_completions.find_or_initialize_by(date: date)

    # Calculate actual minutes from time entries for this goal's category on this date
    if category.present?
      actual_minutes = user.time_entries
                           .where(category: category, date: date)
                           .sum(:duration_minutes)
    else
      # For goals without a specific category, we'd need to define what to measure
      # For now, we'll assume it needs to be manually set
      actual_minutes = completion.actual_minutes || 0
    end

    # Update the completion record
    completion.actual_minutes = actual_minutes
    completion.achieved = (actual_minutes >= target_minutes)

    completion.save!
    completion
  end

  # Calculate weekly progress (for weekly goals)
  def weekly_progress(week_start)
    return 0 unless goal_type == 'weekly'

    week_end = week_start + 6.days

    if category.present?
      user.time_entries
          .where(category: category, date: week_start..week_end)
          .sum(:duration_minutes)
    else
      goal_completions
        .where(date: week_start..week_end)
        .sum(:actual_minutes)
    end
  end

  # Human-readable description
  def description
    desc = "#{target_minutes} minutes"
    desc += " of #{category.name}" if category.present?
    desc += " at #{hour}:00" if hour.present?
    desc += " on #{days_array.join(', ')}" if days_array.present? && days_array.any?
    desc
  end

  private

  def set_defaults
    self.active = true if active.nil?
    # Initialize days_of_week if it's blank
    self.days_of_week = '[]' if days_of_week.blank?
  end

  def hour_required_for_specific_hour_goals
    if goal_type == 'specific_hour' && hour.blank?
      errors.add(:hour, "is required for specific hour goals")
    end
  end

  def hour_not_allowed_for_other_goals
    if goal_type != 'specific_hour' && hour.present?
      # Match the exact message the test expects
      errors.add(:hour, "should not be set for daily or weekly goals")
    end
  end

  def days_of_week_format
    # Validate the days array format
    days_list = days_array
    return if days_list.blank?

    invalid_days = days_list - DAYS_OF_WEEK
    if invalid_days.any?
      errors.add(:days_of_week, "contains invalid days: #{invalid_days.join(', ')}")
    end
  end

  def serialize_days_of_week
    # This is now handled directly in the days_array= setter
    # We keep this method empty to avoid conflicts
  end
end