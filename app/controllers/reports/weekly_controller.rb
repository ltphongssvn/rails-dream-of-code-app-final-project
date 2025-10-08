# app/controllers/reports/weekly_controller.rb
class Reports::WeeklyController < ApplicationController
  def show
    @week_start = params[:week_start] ? Date.parse(params[:week_start]) : Date.current.beginning_of_week
    @week_end = @week_start.end_of_week

    # Get time entries for the week
    @time_entries = current_user.time_entries
                                .where(date: @week_start..@week_end)
                                .includes(:category)

    # Calculate total minutes for the week
    @total_minutes = @time_entries.sum(:duration_minutes)
    @total_hours = (@total_minutes / 60.0).round(1)

    # Group by category for pie chart
    @categories_breakdown = @time_entries
                             .group(:category)
                             .sum(:duration_minutes)
                             .transform_keys { |cat| cat&.name || 'Uncategorized' }

    # Group by date for daily totals - Convert back to hash after sorting
    @time_by_date = @time_entries
                      .group(:date)
                      .sum(:duration_minutes)
                      .sort_by { |date, _minutes| date }
                      .to_h  # Fix for array/hash issue

    # Calculate daily average
    @daily_average = @total_minutes / 7.0

    # Get goals for comparison
    @weekly_goals = current_user.goals
                                .active
                                .where(goal_type: 'weekly')
                                .includes(:category)

    @total_goals_count = @weekly_goals.count  # Add this line

    # Calculate goal progress
    @goal_progress = {}
    @weekly_goals.each do |goal|
      if goal.category
        actual = @categories_breakdown[goal.category.name] || 0
        @goal_progress[goal] = {
          actual: actual,
          target: goal.target_minutes,
          percentage: (actual.to_f / goal.target_minutes * 100).round(1)
        }
      end
    end

    # Prepare data for charts
    @chart_categories = @categories_breakdown.keys
    @chart_values = @categories_breakdown.values

    @daily_labels = (@week_start..@week_end).map { |d| d.strftime('%a') }
    @daily_values = (@week_start..@week_end).map { |date| @time_by_date[date] || 0 }
  end
end