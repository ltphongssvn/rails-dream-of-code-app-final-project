# db/migrate/20251006182945_create_goals.rb
class CreateGoals < ActiveRecord::Migration[8.0]
  def change
    create_table :goals do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, foreign_key: true  # Nullable - some goals aren't category-specific
      t.string :goal_type, null: false  # Required: 'daily', 'weekly', or 'specific_hour'
      t.integer :target_minutes, null: false  # Required: the actual goal amount
      t.integer :hour  # Only used for 'specific_hour' type goals
      t.string :days_of_week, default: '["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]'
      t.boolean :active, null: false, default: true  # New goals are active by default
      t.timestamps
    end
    
    # Index for finding all active goals for a user
    # This is the most common query pattern
    add_index :goals, [:user_id, :active], name: 'index_goals_on_user_and_active'
    
    # Index for finding goals by type for a user
    add_index :goals, [:user_id, :goal_type], name: 'index_goals_on_user_and_type'
    
    # Check constraint to ensure goal_type is valid
    execute <<-SQL
      ALTER TABLE goals 
      ADD CONSTRAINT valid_goal_type 
      CHECK (goal_type IN ('daily', 'weekly', 'specific_hour'));
    SQL
    
    # Check constraint to ensure target_minutes is positive
    execute <<-SQL
      ALTER TABLE goals 
      ADD CONSTRAINT positive_target 
      CHECK (target_minutes > 0);
    SQL
    
    # Check constraint: if goal_type is 'specific_hour', hour must be set
    # Otherwise, hour should be null
    execute <<-SQL
      ALTER TABLE goals 
      ADD CONSTRAINT hour_requirement 
      CHECK (
        (goal_type = 'specific_hour' AND hour IS NOT NULL AND hour >= 0 AND hour <= 23) 
        OR 
        (goal_type != 'specific_hour' AND hour IS NULL)
      );
    SQL
  end
end