# app/controllers/reports/weekly_controller.rb
module Reports
  class WeeklyController < ApplicationController
    def show
      reference_date = params[:date].present? ? Date.parse(params[:date]) : Date.current
      
      @week_start = reference_date.beginning_of_week
      @week_end = reference_date.end_of_week
      
      @time_entries = current_user.time_entries
                                  .where(date: @week_start..@week_end)
                                  .includes(:category)
      
      @total_minutes = @time_entries.sum(:duration_minutes)
      @total_hours = (@total_minutes / 60.0).round(1)
      @daily_average = @total_minutes / 7.0
      
      # Use @time_by_category for consistency with tests
      @time_by_category = @time_entries
                           .group(:category)
                           .sum(:duration_minutes)
                           .transform_keys { |cat| cat&.name || 'Uncategorized' }
      
      # Also keep @categories_breakdown for backward compatibility
      @categories_breakdown = @time_by_category
      
      @time_by_date = @time_entries
                       .group(:date)
                       .sum(:duration_minutes)
                       .sort_by { |date, _minutes| date }
                       .to_h
      
      # Goal achievement calculations
      applicable_goals = current_user.goals
                                     .active
                                     .select do |g|
                                       (@week_start..@week_end).any? { |date| g.applies_on_date?(date) }
                                     end
      
      completions = GoalCompletion.joins(:goal)
                                  .where(goal: applicable_goals, date: @week_start..@week_end)
      
      @goals_achieved_count = completions.where(achieved: true).count
      @goals_missed_count = completions.where(achieved: false).count
      
      total_opportunities = @goals_achieved_count + @goals_missed_count
      @achievement_percentage = if total_opportunities > 0
                                 ((@goals_achieved_count.to_f / total_opportunities) * 100).round
                               else
                                 0
                               end
      
      # Achievement by day
      @achievement_by_day = {}
      (@week_start..@week_end).each do |date|
        day_goals = applicable_goals.select { |g| g.applies_on_date?(date) }
        day_completions = completions.where(date: date)
        achieved = day_completions.where(achieved: true).count
        total = day_completions.count
        @achievement_by_day[date.strftime('%A')] = total > 0 ? ((achieved.to_f / total) * 100).round : 0
      end
      
      # Weekly goals
      @weekly_goals = current_user.goals
                                  .active
                                  .where(goal_type: 'weekly')
                                  .includes(:category)
      
      @total_goals_count = @weekly_goals.count
      
      @goal_progress = {}
      @weekly_goals.each do |goal|
        if goal.category
          actual = @time_by_category[goal.category.name] || 0
          @goal_progress[goal] = {
            actual: actual,
            target: goal.target_minutes,
            percentage: (actual.to_f / goal.target_minutes * 100).round(1)
          }
        end
      end
      
      # Chart data
      @chart_categories = @time_by_category.keys
      @chart_values = @time_by_category.values
      @daily_labels = (@week_start..@week_end).map { |d| d.strftime('%a') }
      @daily_values = (@week_start..@week_end).map { |date| @time_by_date[date] || 0 }
    end
  end
end
