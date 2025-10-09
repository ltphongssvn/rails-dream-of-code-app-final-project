# app/models/goal_completion.rb
class GoalCompletion < ApplicationRecord
  # Associations
  belongs_to :goal
  has_one :user, through: :goal
  has_one :category, through: :goal

  # Validations
  validates :goal, presence: true
  validates :date, presence: true
  validates :actual_minutes,
    numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1440,
      allow_nil: true
    }

  # Prevent duplicate completions for same goal and date
  validates :goal_id, uniqueness: { scope: :date,
    message: "already has a completion record for this date" }

  # Scopes for querying
  scope :achieved, -> { where(achieved: true) }
  scope :missed, -> { where(achieved: false).where("actual_minutes > 0") }
  scope :pending, -> { where(achieved: false, actual_minutes: 0) }
  scope :for_date, ->(date) { where(date: date) }
  scope :recent, -> { order(date: :desc) }
  scope :date_range, ->(start_date, end_date) {
    where(date: start_date..end_date)
  }

  # Callbacks
  before_validation :set_achievement_status, if: :actual_minutes_changed?
  after_save :update_user_streaks, if: :saved_change_to_achieved?

  # Calculate if goal was achieved based on actual vs target minutes
  def calculate_achievement
    return nil if actual_minutes.nil? || goal.nil?
    actual_minutes >= goal.target_minutes
  end

  # Percentage of goal completed
  def completion_percentage
    return 0 if actual_minutes.nil? || goal.target_minutes.nil? || goal.target_minutes == 0
    [(actual_minutes.to_f / goal.target_minutes * 100).round(1), 100.0].min
  end

  # Check if this completion is part of a streak
  def part_of_streak?
    return false unless achieved?

    # Check previous applicable date
    previous_date = find_previous_applicable_date
    return true if previous_date.nil? # First completion starts a streak

    previous_completion = goal.goal_completions.find_by(date: previous_date)
    previous_completion&.achieved? || false
  end

  # Calculate current streak length
  def streak_length
    return 0 unless achieved?

    count = 1
    current_date = date - 1.day

    # Count backwards
    while current_date >= goal.created_at.to_date
      if goal.applies_to_date?(current_date)
        completion = goal.goal_completions.find_by(date: current_date)
        break unless completion&.achieved?
        count += 1
      end
      current_date -= 1.day
    end

    # Count forwards from the day after
    current_date = date + 1.day
    while current_date <= Date.current
      if goal.applies_to_date?(current_date)
        completion = goal.goal_completions.find_by(date: current_date)
        break unless completion&.achieved?
        count += 1
      end
      current_date += 1.day
    end

    count
  end

  # Status for display
  def status
    if achieved == false && actual_minutes == 0
      'pending'
    elsif achieved?
      'achieved'
    else
      'missed'
    end
  end

  # Human-readable summary
  def summary
    if achieved == false && actual_minutes == 0
      "Goal pending: #{goal.target_minutes} minutes target"
    elsif achieved?
      "Achieved: #{actual_minutes}/#{goal.target_minutes} minutes (#{completion_percentage}%)"
    else
      "Missed: #{actual_minutes || 0}/#{goal.target_minutes} minutes (#{completion_percentage}%)"
    end
  end

  private

  def set_achievement_status
    self.achieved = calculate_achievement if actual_minutes.present? && actual_minutes > 0
  end

  def find_previous_applicable_date
    current = date - 1.day
    while current >= goal.created_at.to_date
      return current if goal.applies_to_date?(current)
      current -= 1.day
    end
    nil
  end

  # Placeholder for future streak tracking feature
  def update_user_streaks
    # This would update a user's streak statistics
    # Implementation would depend on how you want to track streaks
    # Could trigger notifications, badges, etc.
  end
end