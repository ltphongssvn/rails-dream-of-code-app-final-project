# app/controllers/reports/daily_controller.rb
class Reports::DailyController < ApplicationController
  before_action :require_authentication
  
  def daily
    Rails.logger.debug "="*80
    Rails.logger.debug "DailyController#daily starting"
    Rails.logger.debug "Params received: #{params.inspect}"
    Rails.logger.debug "Request format: #{request.format}"
    
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    Rails.logger.debug "Date being used: #{@date}"
    
    # Get time entries for the specific date
    @time_entries = current_user.time_entries
                                .includes(:category)
                                .where(date: @date)
                                .order(:hour)
    Rails.logger.debug "Time entries found: #{@time_entries.count}"
    
    # Calculate total minutes
    @total_minutes = @time_entries.sum(:duration_minutes)
    Rails.logger.debug "Total minutes calculated: #{@total_minutes}"
    
    # Group by category and sum minutes
    raw_category_data = current_user.time_entries
                          .where(date: @date)
                          .joins(:category)
                          .group('categories.name')
                          .sum(:duration_minutes)
    
    Rails.logger.debug "Raw category data type: #{raw_category_data.class}"
    Rails.logger.debug "Raw category data: #{raw_category_data.inspect}"
    
    # Apply sorting and convert back to hash to maintain both order and hash access
    # The sort_by returns an array of [key, value] pairs
    # Converting back to hash preserves the sort order in Ruby 1.9+
    sorted_array = raw_category_data.sort_by { |_category, minutes| -minutes }
    @time_by_category = sorted_array.to_h
    
    Rails.logger.debug "Final @time_by_category type: #{@time_by_category.class}"
    Rails.logger.debug "Final @time_by_category value: #{@time_by_category.inspect}"
    
    # Get goals for the day
    applicable_goals = current_user.goals
                                   .active
                                   .select { |g| g.applies_on_date?(@date) }
    Rails.logger.debug "Applicable goals count: #{applicable_goals.count}"
    
    # Get goal completions for the day
    completions = GoalCompletion.joins(:goal)
                                .where(goal: applicable_goals, date: @date)
    
    @goals_achieved_count = completions.where(achieved: true).count
    @goals_missed_count = completions.where(achieved: false).count
    Rails.logger.debug "Goals achieved: #{@goals_achieved_count}, missed: #{@goals_missed_count}"
    
    total_applicable = @goals_achieved_count + @goals_missed_count
    @achievement_percentage = if total_applicable > 0
                               ((@goals_achieved_count.to_f / total_applicable) * 100).round
                             else
                               0
                             end
    Rails.logger.debug "Achievement percentage: #{@achievement_percentage}"
    
    Rails.logger.debug "About to respond with format negotiation"
    respond_to do |format|
      format.html do
        Rails.logger.debug "Responding with HTML format"
        render :daily
      end
      format.json do
        Rails.logger.debug "Responding with JSON format"
        render json: { 
          date: @date,
          total_minutes: @total_minutes,
          time_by_category: @time_by_category,
          achievement_percentage: @achievement_percentage 
        }
      end
    end
    Rails.logger.debug "DailyController#daily completed"
    Rails.logger.debug "="*80
  rescue => e
    Rails.logger.error "Error in DailyController#daily: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
