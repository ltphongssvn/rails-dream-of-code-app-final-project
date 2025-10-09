# app/controllers/time_entries_controller.rb
class TimeEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_time_entry, only: [:edit, :update, :destroy]
  before_action :set_categories, only: [:new, :create, :edit, :update]

  def index
    @date = params[:date] ? Date.parse(params[:date]) : Date.current

    @time_entries = current_user.time_entries
                                .for_date(@date)
                                .includes(:category)
                                .order(:hour)

    # Prepare hourly grid (24 hours)
    @hourly_entries = prepare_hourly_grid(@time_entries)

    # Calculate daily statistics
    @total_minutes = @time_entries.sum(:duration_minutes)

    # Fix: Create a separate query for category breakdown without the order clause
    @categories_breakdown = current_user.time_entries
                                        .for_date(@date)
                                        .joins(:category)
                                        .group('categories.id', 'categories.name')
                                        .sum(:duration_minutes)
  end

  def new
    @time_entry = current_user.time_entries.build(
      date: params[:date] || Date.current,
      hour: params[:hour] || Time.current.hour
    )
  end

  def create
    @time_entry = current_user.time_entries.build(time_entry_params)

    if @time_entry.save
      check_goal_completions(@time_entry.date)
      redirect_to time_entries_path(date: @time_entry.date),
                  notice: 'Time entry logged successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # @time_entry is set by before_action
  end

  def update
    if @time_entry.update(time_entry_params)
      check_goal_completions(@time_entry.date)
      redirect_to time_entries_path(date: @time_entry.date),
                  notice: 'Time entry updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    date = @time_entry.date
    @time_entry.destroy
    check_goal_completions(date)

    redirect_to time_entries_path(date: date),
                notice: 'Time entry deleted successfully.'
  end

  private

  def set_time_entry
    @time_entry = current_user.time_entries.find(params[:id])
  end

  def set_categories
    @categories = current_user.categories.alphabetical
  end

  def time_entry_params
    params.require(:time_entry).permit(:date, :hour, :duration_minutes, :category_id, :notes)
  end

  def prepare_hourly_grid(entries)
    grid = {}
    (0..23).each do |hour|
      grid[hour] = entries.find { |e| e.hour == hour }
    end
    grid
  end

  def check_goal_completions(date)
    # Update goal completions for the given date
    current_user.goals.active.each do |goal|
      goal.check_and_record_completion(date) if goal.applies_on_date?(date)
    end
  end

  def authenticate_user!
    redirect_to new_session_path, alert: 'Please sign in to continue.' unless current_user
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
end