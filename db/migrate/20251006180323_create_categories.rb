class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color
      t.integer :parent_category_id  # Self-referential foreign key, nullable for top-level categories
      t.timestamps
    end
    
    # Add index for faster queries when finding subcategories
    add_index :categories, :parent_category_id
    
    # Add foreign key constraint after table creation
    # References the same categories table (self-referential)
    add_foreign_key :categories, :categories, column: :parent_category_id
  end
end
