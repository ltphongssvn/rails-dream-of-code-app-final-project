# app/models/category.rb
class Category < ApplicationRecord
  # Associations
  belongs_to :user

  # Self-referential associations for parent-child relationship
  belongs_to :parent_category, class_name: 'Category', optional: true
  has_many :subcategories, class_name: 'Category', foreign_key: 'parent_category_id', dependent: :destroy

  # Association with time_entries - use restrict_with_error to prevent deletion
  has_many :time_entries, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :user_id, message: "has already been taken" }

  validates :color, format: {
    with: /\A#[0-9A-Fa-f]{6}\z/,
    message: "must be a valid hex color (e.g., #FF5733)"
  }, allow_blank: true

  # Ensure a category cannot be its own parent
  validate :parent_category_cannot_be_self

  # Ensure no circular references
  validate :no_circular_reference

  # Callbacks
  before_validation :assign_default_color, on: :create

  # Scopes for common queries
  scope :top_level, -> { where(parent_category_id: nil) }
  scope :with_subcategories, -> { includes(:subcategories) }
  scope :alphabetical, -> { order(:name) }

  # Instance methods

  # Returns the full category path like "Work > Programming > Rails"
  def full_name
    if parent_category
      "#{parent_category.full_name} > #{name}"
    else
      name
    end
  end

  # Alias for compatibility
  alias_method :full_path, :full_name

  # Calculate total time for a period, optionally including subcategories
  def total_time_for_period(start_date, end_date, include_children: false)
    if include_children
      category_ids = [id] + descendant_ids
      TimeEntry.where(category_id: category_ids, date: start_date..end_date)
               .sum(:duration_minutes)
    else
      time_entries.where(date: start_date..end_date)
                  .sum(:duration_minutes)
    end
  end

  # Get all descendant category IDs (recursive)
  def descendant_ids
    result = []
    subcategories.each do |subcategory|
      result << subcategory.id
      result.concat(subcategory.descendant_ids)
    end
    result
  end

  # Returns how deep this category is in the hierarchy (0 for top-level)
  def depth_level
    parent_category ? parent_category.depth_level + 1 : 0
  end

  # Returns the top-most parent category
  def root_category
    parent_category ? parent_category.root_category : self
  end

  private

  def parent_category_cannot_be_self
    if parent_category_id.present? && parent_category_id == id
      errors.add(:parent_category_id, "can't be a circular reference")
    end
  end

  def no_circular_reference
    if parent_category_id.present? && parent_category_id_changed?
      current = parent_category
      while current
        if current.id == id
          errors.add(:parent_category_id, "can't be a circular reference")
          break
        end
        current = current.parent_category
      end
    end
  end

  def assign_default_color
    if color.blank?
      # Generate a random but pleasant color
      self.color = "#%06x" % (rand * 0xffffff)
    end
  end
end