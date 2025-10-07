# app/controllers/categories_controller.rb
class CategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_category, only: [:show, :edit, :update, :destroy, :subcategories]
  before_action :set_available_parent_categories, only: [:new, :create, :edit, :update]

  def index
    # Show all categories for the current user, organized hierarchically
    @categories = current_user.categories.includes(:subcategories, :parent_category).top_level.alphabetical
    
    # If this is being called from the reports namespace, show all categories for breakdown
    if request.path.include?('reports')
      @categories = current_user.categories.includes(:time_entries).alphabetical
    end
  end

  def show
    # Display a single category with its details, subcategories, and recent time entries
    @subcategories = @category.subcategories.alphabetical
    @recent_entries = @category.time_entries.order(date: :desc, hour: :desc).limit(10)
    
    # Calculate statistics for the current month
    start_of_month = Date.current.beginning_of_month
    end_of_month = Date.current.end_of_month
    @total_time_this_month = @category.total_time_for_period(start_of_month, end_of_month, include_children: true)
  end

  def new
    @category = current_user.categories.build
    # Set default color if not provided
    @category.color ||= generate_random_color
  end

  def create
    @category = current_user.categories.build(category_params)
    
    if @category.save
      redirect_to categories_path, notice: 'Category was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # @category is set by before_action
    # Need to ensure user can't set this category as its own parent
  end

  def update
    if @category.update(category_params)
      redirect_to categories_path, notice: 'Category was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @category.time_entries.exists?
      redirect_to categories_path, alert: 'Cannot delete category that has time entries. Please reassign or delete the time entries first.'
    else
      @category.destroy
      redirect_to categories_path, notice: 'Category was successfully deleted.'
    end
  end

  def subcategories
    # Return subcategories as JSON for dynamic dropdowns
    # This is useful when building forms where selecting a parent category
    # should show its available subcategories
    @subcategories = @category.subcategories.alphabetical
    render json: @subcategories.map { |c| { id: c.id, name: c.name, color: c.color } }
  end

  private

  def set_category
    @category = current_user.categories.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to categories_path, alert: 'Category not found.'
  end

  def set_available_parent_categories
    # When creating or editing, show all top-level categories as potential parents
    # Exclude the current category and its descendants to prevent circular references
    if @category&.persisted?
      # Editing existing category - exclude self and descendants
      excluded_ids = [@category.id] + @category.descendant_ids
      @available_parents = current_user.categories.where.not(id: excluded_ids).top_level.alphabetical
    else
      # Creating new category - show all top-level categories
      @available_parents = current_user.categories.top_level.alphabetical
    end
  end

  def category_params
    params.require(:category).permit(:name, :color, :parent_category_id)
  end

  def authenticate_user!
    redirect_to new_session_path, alert: 'Please sign in to continue.' unless current_user
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def generate_random_color
    "#%06x" % (rand * 0xffffff)
  end
end
