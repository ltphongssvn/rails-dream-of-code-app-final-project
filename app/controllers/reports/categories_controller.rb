# app/controllers/reports/categories_controller.rb
module Reports
  class CategoriesController < ApplicationController
    # All report actions require authentication since reports show user-specific data
    # The Authentication concern included in ApplicationController handles this

    # GET /reports/category_breakdown
    # Displays a category breakdown report showing how time is distributed across categories
    def index
      # Allow users to optionally filter the report by date range
      # If no dates provided, show all-time category distribution
      # This flexibility lets users analyze category patterns for specific periods
      # or understand their overall long-term category allocation patterns
      if params[:start_date].present? && params[:end_date].present?
        @start_date = Date.parse(params[:start_date])
        @end_date = Date.parse(params[:end_date])
        @date_range = @start_date..@end_date
      else
        # No date filter means show all-time data
        @start_date = nil
        @end_date = nil
        @date_range = nil
      end

      # Query time entries for the current user, optionally filtered by date range
      # We include the category association to access category names and parent relationships
      @time_entries = if @date_range
                       current_user.time_entries
                                   .where(date: @date_range)
                                   .includes(:category)
                     else
                       current_user.time_entries
                                   .includes(:category)
                     end

      # Calculate total minutes tracked across all categories
      # This denominator is crucial for calculating percentage distributions
      @total_minutes = @time_entries.sum(:duration_minutes)

      # Group time entries by category and calculate totals for each category
      # This shows direct time allocation without considering subcategory rollups yet
      # Returns a hash: { category_id => total_minutes }
      category_totals = @time_entries
                          .joins(:category)
                          .group('categories.id')
                          .sum(:duration_minutes)

      # Build a comprehensive category breakdown structure that includes:
      # - Direct time: minutes logged directly to this category
      # - Total time: direct time plus all time logged to subcategories (for parent categories)
      # - Percentage: what proportion of total tracked time this category represents
      # - Subcategories: array of child categories for hierarchical display
      @category_breakdown = []

      # Get all categories for the current user to build the full hierarchy
      all_categories = current_user.categories.includes(:parent_category, :subcategories)

      # Focus on top-level categories (those without parents) first
      # We'll build the hierarchy from the top down for clearer presentation
      top_level_categories = all_categories.where(parent_category_id: nil)

      top_level_categories.each do |category|
        # Calculate direct time for this category
        direct_minutes = category_totals[category.id] || 0

        # Calculate total time including all subcategories recursively
        # This is where the hierarchical nature adds significant value
        total_minutes = calculate_category_total_with_subcategories(category, category_totals)

        # Calculate percentage of overall tracked time
        # Avoid division by zero if no time has been tracked
        percentage = @total_minutes > 0 ? ((total_minutes.to_f / @total_minutes) * 100).round(1) : 0

        # Build subcategory breakdown for hierarchical display
        subcategory_data = category.subcategories.map do |subcat|
          sub_minutes = category_totals[subcat.id] || 0
          sub_percentage = @total_minutes > 0 ? ((sub_minutes.to_f / @total_minutes) * 100).round(1) : 0

          {
            category: subcat,
            direct_minutes: sub_minutes,
            percentage: sub_percentage
          }
        end.sort_by { |sc| -sc[:direct_minutes] } # Sort subcategories by time descending

        # Only include categories that have time tracked
        # This keeps the report focused on actual activity rather than showing empty categories
        if total_minutes > 0
          @category_breakdown << {
            category: category,
            direct_minutes: direct_minutes,
            total_minutes: total_minutes,
            percentage: percentage,
            subcategories: subcategory_data
          }
        end
      end

      # Sort categories by total time descending so the most time-consuming categories appear first
      # This ordering helps users quickly identify where their time is going
      @category_breakdown.sort_by! { |cb| -cb[:total_minutes] }

      # Identify the top 5 categories by time consumption
      # This highlights where users are investing most of their effort
      @top_categories = @category_breakdown.take(5)

      # Calculate category diversity metrics
      # These help users understand whether their time is concentrated or distributed
      if @category_breakdown.any?
        # Count how many categories have meaningful time (more than 1% of total)
        @active_categories_count = @category_breakdown.count { |cb| cb[:percentage] > 1.0 }

        # Calculate concentration: what percentage of time goes to the top category
        # High concentration might indicate over-focus on one area
        @top_category_concentration = @category_breakdown.first[:percentage]

        # Calculate whether time is well-distributed or heavily concentrated
        # If top 3 categories consume more than 75% of time, allocation is concentrated
        top_three_percentage = @category_breakdown.take(3).sum { |cb| cb[:percentage] }
        @distribution_pattern = top_three_percentage > 75 ? 'concentrated' : 'distributed'
      end

      # Find goals associated with categories to show alignment between goals and actual time
      # This helps users see whether they're investing time in categories tied to their goals
      @category_goals = current_user.goals
                                    .active
                                    .where.not(category_id: nil)
                                    .includes(:category)

      # For each category goal, compare target minutes against actual time tracked
      # This reveals whether users are meeting, exceeding, or falling short of their category goals
      @goal_alignment = @category_goals.map do |goal|
        category_data = @category_breakdown.find { |cb| cb[:category].id == goal.category_id }
        actual_minutes = category_data ? category_data[:total_minutes] : 0

        # For date-filtered reports, calculate expected target based on applicable days
        if @date_range
          applicable_days = (@start_date..@end_date).count { |date| goal.applies_to_date?(date) }
          expected_target = goal.target_minutes * applicable_days
        else
          # For all-time reports, we can't calculate a meaningful target comparison
          # since we don't know how many days the goal has been active
          expected_target = nil
        end

        {
          goal: goal,
          category: goal.category,
          actual_minutes: actual_minutes,
          expected_target: expected_target,
          alignment: expected_target ? ((actual_minutes.to_f / expected_target) * 100).round : nil
        }
      end.select { |ga| ga[:expected_target] } # Only include goals where we can calculate alignment
    end

    private

    # Recursively calculate total time for a category including all its subcategories
    # This method handles nested category hierarchies of arbitrary depth
    def calculate_category_total_with_subcategories(category, category_totals)
      # Start with direct time logged to this category
      total = category_totals[category.id] || 0

      # Add time from all subcategories recursively
      # This handles multi-level nesting like Work > Projects > Client A
      category.subcategories.each do |subcat|
        total += calculate_category_total_with_subcategories(subcat, category_totals)
      end

      total
    end

    # Helper method to get current user from the Authentication concern
    # The Authentication concern sets Current.session which has a user association
    def current_user
      Current.session&.user
    end
  end
end