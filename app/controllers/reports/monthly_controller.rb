# app/controllers/reports/monthly_controller.rb
module Reports
  class MonthlyController < ApplicationController
    # All report actions require authentication since reports show user-specific data
    # The Authentication concern included in ApplicationController handles this

    # GET /reports/monthly
    # Displays a monthly time tracking and goal achievement report for a specified month
    def show
      # Allow users to view reports for any month, defaulting to the current month
      # The date parameter can be any date within the month of interest
      # Rails will calculate the proper month boundaries from this date
      reference_date = params[:date].present? ? Date.parse(params[:date]) : Date.current

      # Calculate the start and end dates for the month containing the reference date
      # These boundaries define the exact month period we're reporting on
      # Months have variable lengths (28-31 days) which these methods handle correctly
      @month_start = reference_date.beginning_of_month
      @month_end = reference_date.end_of_month

      # Calculate the actual number of days in this month for accurate averaging
      # This is important because dividing by a constant 30 would give incorrect averages
      # for months with 28, 29, or 31 days
      @days_in_month = (@month_end - @month_start).to_i + 1

      # Query all time entries for the current user within this month's date range
      # We include the category association to avoid N+1 queries when grouping by category
      @time_entries = current_user.time_entries
                                  .where(date: @month_start..@month_end)
                                  .includes(:category)

      # Calculate total minutes tracked across the entire month
      # This shows the user's total time investment over the full monthly period
      @total_minutes = @time_entries.sum(:duration_minutes)

      # Calculate daily average using the actual number of days in the month
      # This gives users an accurate sense of their typical daily commitment
      # during this particular month, accounting for the month's actual length
      @daily_average = (@total_minutes / @days_in_month.to_f).round

      # Calculate weekly average by dividing total minutes by number of weeks in the month
      # Most months span parts of 5 different calendar weeks, but we approximate
      # by dividing by 4.0 to show a typical week's time investment during this month
      @weekly_average = (@total_minutes / 4.0).round

      # Group time entries by category to show how time was distributed across the month
      # This reveals sustained priorities over the long term, which tend to be more
      # reliable indicators of actual time allocation than daily or weekly distributions
#       @time_by_category = @time_entries
#                             .joins(:category)
#                             .group('categories.name')
#                             .sum(:duration_minutes)
#                             .sort_by { |_category, minutes| -minutes } # Sort by minutes descending

      # Group time entries by category to show how time was distributed across the month
      # This reveals sustained priorities over the long term, which tend to be more
      # reliable indicators of actual time allocation than daily or weekly distributions
      @time_by_category = @time_entries
                            .joins(:category)
                            .group('categories.name')
                            .sum(:duration_minutes)
                            .sort_by { |_category, minutes| -minutes }
                            .to_h # Convert sorted array back to hash for hash-style access


      # Group time entries by week to show how time tracking varied throughout the month
      # This helps users see whether they maintained consistency or if productivity
      # fluctuated significantly from week to week within the month
      @time_by_week = @time_entries
                        .group_by { |entry| entry.date.beginning_of_week }
                        .transform_values { |entries| entries.sum(&:duration_minutes) }
                        .sort_by { |week_start, _minutes| week_start }.to_h

      # Group time entries by date to enable detailed daily views if needed
      # This allows the view to optionally display a calendar-style visualization
      # showing which days had high activity versus low activity
#       @time_by_date = @time_entries
#                         .group(:date)
#                         .sum(:duration_minutes)
#                         .sort_by { |date, _minutes| date } # Sort chronologically

      # Group time entries by date to enable detailed daily views if needed
      # This allows the view to optionally display a calendar-style visualization
      # showing which days had high activity versus low activity
      @time_by_date = @time_entries
                        .group(:date)
                        .sum(:duration_minutes)
                        .sort_by { |date, _minutes| date }
                        .to_h # Convert sorted array back to hash for hash-style access


      # Find all active goals and determine which ones applied during this month
      # Goals may have days_of_week restrictions, so we need to check across
      # the entire month to see which goals were applicable
      all_active_goals = current_user.goals.active

      # For monthly reports, we need to consider all days in the month
      # and determine which goals applied on at least one day during the month
      @applicable_goals = all_active_goals.select do |goal|
        # A goal is applicable to the month if it applies to at least one day in the month
        (@month_start..@month_end).any? { |date| goal.applies_to_date?(date) }
      end

      # Query all goal completions for applicable goals within this month
      # This shows us which goals were achieved and which were missed
      # across the entire monthly period
      @goal_completions = GoalCompletion
                           .where(goal: @applicable_goals, date: @month_start..@month_end)
                           .includes(:goal)

      # Calculate goal achievement statistics for the month
      # These metrics help users understand their overall performance
      # across the full monthly period rather than just days or weeks
      @goals_achieved_count = @goal_completions.achieved.count
      @goals_missed_count = @goal_completions.missed.count

      # For monthly reports, we need to count total goal opportunities across all days
      # A daily goal that applies 5 days per week represents approximately 20-22 opportunities
      # in a typical month, depending on how many weeks the month spans
      total_goal_opportunities = 0
      (@month_start..@month_end).each do |date|
        @applicable_goals.each do |goal|
          total_goal_opportunities += 1 if goal.applies_to_date?(date)
        end
      end

      # Calculate achievement percentage based on total opportunities across the month
      # This gives users a comprehensive view of their performance over the long term
      @achievement_percentage = if total_goal_opportunities > 0
                                 (@goals_achieved_count.to_f / total_goal_opportunities * 100).round
                               else
                                 0
                               end

      # Calculate achievement trends by week within the month
      # This helps users see whether their goal performance improved, declined,
      # or remained stable as the month progressed
      @achievement_by_week = {}
      @time_by_week.keys.each do |week_start|
        week_end = [week_start + 6.days, @month_end].min
        week_completions = @goal_completions.where(date: week_start..week_end)

        week_goal_opportunities = 0
        (week_start..week_end).each do |date|
          next if date < @month_start || date > @month_end
          @applicable_goals.each do |goal|
            week_goal_opportunities += 1 if goal.applies_to_date?(date)
          end
        end

        week_achieved = week_completions.achieved.count
        if week_goal_opportunities > 0
          @achievement_by_week[week_start] = ((week_achieved.to_f / week_goal_opportunities) * 100).round
        else
          @achievement_by_week[week_start] = 0
        end
      end

      # Calculate the most productive day of the month
      # This helps users identify their peak performance day
      if @time_by_date.any?
        @most_productive_date = @time_by_date.max_by { |_date, minutes| minutes }
      end

      # Calculate the least productive day (excluding zero-minute days)
      # This helps users identify potential problem areas
      productive_days = @time_by_date.select { |_date, minutes| minutes > 0 }
      if productive_days.any?
        @least_productive_date = productive_days.min_by { |_date, minutes| minutes }
      end
    end

    private

    # Helper method to get current user from the Authentication concern
    # The Authentication concern sets Current.session which has a user association
    def current_user
      Current.session&.user
    end
  end
end