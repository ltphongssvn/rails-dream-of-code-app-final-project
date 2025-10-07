# app/controllers/goals_controller.rb
class GoalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_goal, only: [:show, :edit, :update, :destroy]
  before_action :set_categories, only: [:new, :create, :edit, :update]

  def index
    @active_goals = current_user.goals.active.includes(:category, :goal_completions).order(created_at: :desc)
    @inactive_goals = current_user.goals.inactive.includes(:category).order(created_at: :desc)

    @week_start = Date.current.beginning_of_week
    @week_end = @week_start + 6.days
  end

  def show
    @recent_completions = @goal.goal_completions
                               .recent
                               .limit(30)
                               .includes(:goal)

    @today_completion = @goal.completion_for_date(Date.current)
    @week_start = Date.current.beginning_of_week
    @week_end = @week_start + 6.days
    @month_start = Date.current.beginning_of_month
    @month_end = @month_start + 1.month - 1.day

    @week_percentage = @goal.completion_percentage(@week_start, @week_end) || 0
    @month_percentage = @goal.completion_percentage(@month_start, @month_end) || 0
    @current_streak = @goal.current_streak || 0
  end

  def new
    @goal = current_user.goals.build
    @goal.goal_type = 'daily'
    @goal.days_array = []
  end

  def create
    @goal = current_user.goals.build(goal_params)

    if params[:goal] && params[:goal][:days_array].present?
      @goal.days_array = params[:goal][:days_array].reject(&:blank?)
    else
      @goal.days_array = []
    end

    if @goal.save
      redirect_to goals_path, notice: 'Goal was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
#     @goal.send(:deserialize_days_of_week) if @goal.days_of_week.present?
    # @goal is set by before_action
    # days_array is automatically deserialized by the after_initialize callback
    # No explicit deserialization needed here
  end

  def update
    if params[:goal] && params[:goal].key?(:days_array)
      if params[:goal][:days_array].present?
        clean_days = params[:goal][:days_array].reject(&:blank?)
        @goal.days_array = clean_days
      else
        @goal.days_array = []
      end
    end

    @goal.assign_attributes(goal_params)

    if @goal.save
      redirect_to goal_path(@goal), notice: 'Goal was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @goal.destroy
    redirect_to goals_path, notice: 'Goal was successfully deleted.'
  end

  private

  def set_goal
    @goal = current_user.goals.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to goals_path, alert: 'Goal not found.'
  end

  def set_categories
    @categories = current_user.categories.alphabetical
  end

  def goal_params
    params.require(:goal).permit(
      :goal_type,
      :target_minutes,
      :hour,
      :category_id,
      :active
    )
  end

  def authenticate_user!
    redirect_to new_session_path, alert: 'Please sign in to continue.' unless current_user
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
end