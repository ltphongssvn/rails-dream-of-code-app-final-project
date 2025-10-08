# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @today = Date.current
    @current_week = @today.beginning_of_week..@today.end_of_week
    
    # Today's progress
    @todays_entries = current_user.time_entries_for_date(@today)
    @todays_minutes = @todays_entries.sum(:duration_minutes)
    
    # Week's progress
    @week_entries = current_user.time_entries
                                .where(date: @current_week)
                                .includes(:category)
    @week_minutes = @week_entries.sum(:duration_minutes)
    
    # Active goals and their status
    @daily_goals = current_user.active_goals_for_day(@today)
                               .includes(:category, :goal_completions)
    @goal_statuses = calculate_goal_statuses(@daily_goals, @today)
    
    # Category breakdown for the week
    @category_breakdown = @week_entries.group(:category)
                                       .sum(:duration_minutes)
                                       .sort_by { |_, minutes| -minutes }
    
    # Recent streaks
    @streaks = calculate_current_streaks(@daily_goals)
    
    # Hour-by-hour comparison with yesterday
    @comparison = prepare_comparison(@today)
  end

  private

  def calculate_goal_statuses(goals, date)
    goals.map do |goal|
      completion = goal.completion_for_date(date)
      {
        goal: goal,
        completion: completion,
        status: completion&.status || 'pending',
        percentage: completion&.completion_percentage || 0,
        actual_minutes: completion&.actual_minutes || 0
      }
    end
  end

  def calculate_current_streaks(goals)
    goals.map do |goal|
      {
        goal: goal,
        streak: goal.current_streak,
        completion_rate: goal.completion_rate
      }
    end
  end

  def prepare_comparison(date)
    today_entries = current_user.time_entries_for_date(date)
    yesterday_entries = current_user.time_entries_for_date(date - 1.day)
    
    comparison = {}
    (0..23).each do |hour|
      comparison[hour] = {
        today: today_entries.find { |e| e.hour == hour },
        yesterday: yesterday_entries.find { |e| e.hour == hour }
      }
    end
    comparison
  end

  def authenticate_user!
    redirect_to new_session_path, alert: 'Please sign in to continue.' unless current_user
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
end