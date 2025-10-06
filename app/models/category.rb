# app/models/category.rb
class Category < ApplicationRecord
  # Associations
  belongs_to :user
  
  # Self-referential associations for parent-child relationship
  belongs_to :parent_category, class_name: 'Category', optional: true
  has_many :subcategories, class_name: 'Category', foreign_key: 'parent_category_id', dependent: :destroy
  
  # Future association with time_entries (to be added later)
  # has_many :time_entries, dependent: :destroy
  
  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :color, format: { 
    with: /\A#[0-9A-Fa-f]{6}\z/, 
    message: "must be a valid hex color code (e.g., #FF5733)" 
  }, allow_blank: true
  
  # Ensure a category cannot be its own parent
  validate :parent_category_cannot_be_self
  
  # Ensure no circular references (a parent can't have its child as a parent)
  validate :no_circular_reference
  
  # Scopes for common queries
  scope :top_level, -> { where(parent_category_id: nil) }
  scope :with_subcategories, -> { includes(:subcategories) }
  
  # Instance methods
  def full_path
    # Returns the full category path like "Work > Meetings > Daily Standup"
    if parent_category
      "#{parent_category.full_path} > #{name}"
    else
      name
    end
  end
  
  def depth_level
    # Returns how deep this category is in the hierarchy (0 for top-level)
    parent_category ? parent_category.depth_level + 1 : 0
  end
  
  def root_category
    # Returns the top-most parent category
    parent_category ? parent_category.root_category : self
  end
  
  private
  
  def parent_category_cannot_be_self
    if parent_category_id.present? && parent_category_id == id
      errors.add(:parent_category, "can't be the same as the category itself")
    end
  end
  
  def no_circular_reference
    if parent_category_id.present? && parent_category_id_changed?
      # Check if setting this parent would create a circular reference
      current = parent_category
      while current
        if current.id == id
          errors.add(:parent_category, "would create a circular reference")
          break
        end
        current = current.parent_category
      end
    end
  end
end