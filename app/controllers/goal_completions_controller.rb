# app/controllers/goal_completions_controller.rb
class GoalCompletionsController < ApplicationController
  # All actions require authentication since goal completions are user-specific
  # The Authentication concern provides the require_authentication callback

  # Load the parent goal before any action to ensure it exists and belongs to current user
  before_action :set_goal
  before_action :set_goal_completion, only: [:update]

  # POST /goals/:goal_id/goal_completions
  # Creates a new completion record for a goal on a specific date
  def create
    # Find or initialize a completion record for the specified date
    # This allows updating an existing completion if one already exists
    # rather than failing with a duplicate validation error
    @goal_completion = @goal.goal_completions.find_or_initialize_by(
      date: goal_completion_params[:date]
    )

    # Update the completion with the actual minutes spent
    # The GoalCompletion model's before_validation callback will automatically
    # calculate whether the goal was achieved based on actual vs target minutes
    @goal_completion.actual_minutes = goal_completion_params[:actual_minutes]

    if @goal_completion.save
      # Successfully created or updated the completion record
      # The model has automatically calculated achievement status and percentage
      redirect_to goal_path(@goal),
                  notice: "Goal completion recorded: #{@goal_completion.summary}"
    else
      # Validation failed - could be invalid actual_minutes or other issues
      # Redirect back to the goal page with error details
      redirect_to goal_path(@goal),
                  alert: "Unable to record completion: #{@goal_completion.errors.full_messages.join(', ')}"
    end
  end

  # PATCH/PUT /goals/:goal_id/goal_completions/:id
  # Updates an existing completion record with new actual minutes
  def update
    # Update the actual minutes on the existing completion record
    # The model's callback will recalculate achievement status automatically
    @goal_completion.actual_minutes = goal_completion_params[:actual_minutes]

    if @goal_completion.save
      # Successfully updated the completion record
      redirect_to goal_path(@goal),
                  notice: "Goal completion updated: #{@goal_completion.summary}"
    else
      # Validation failed during update
      redirect_to goal_path(@goal),
                  alert: "Unable to update completion: #{@goal_completion.errors.full_messages.join(', ')}"
    end
  end

  private

  # Load the parent goal and verify it belongs to the current user
  # This ensures users can only create/update completions for their own goals
  def set_goal
    @goal = current_user.goals.find(params[:goal_id])
  rescue ActiveRecord::RecordNotFound
    # Goal doesn't exist or doesn't belong to current user
    redirect_to goals_path, alert: 'Goal not found or access denied.'
  end

  # Load the specific goal completion being updated
  # This only runs for the update action
  def set_goal_completion
    @goal_completion = @goal.goal_completions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    # Completion record doesn't exist for this goal
    redirect_to goal_path(@goal), alert: 'Completion record not found.'
  end

  # Strong parameters - whitelist the attributes that can be mass-assigned
  # Only allow date and actual_minutes to be set from user input
  # The achieved status is calculated automatically by the model
  def goal_completion_params
    params.require(:goal_completion).permit(:date, :actual_minutes)
  end

  # Helper method to get current user from the Authentication concern
  # This is provided by the Authentication concern included in ApplicationController
  def current_user
    Current.session&.user
  end
end