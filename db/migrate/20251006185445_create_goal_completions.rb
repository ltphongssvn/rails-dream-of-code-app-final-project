# db/migrate/20251006185445_create_goal_completions.rb
class CreateGoalCompletions < ActiveRecord::Migration[8.0]
  def change
    create_table :goal_completions do |t|
      t.references :goal, null: false, foreign_key: true
      t.date :date, null: false  # Required - must know when this completion occurred
      t.boolean :achieved, null: false, default: false  # Explicit true/false, no ambiguity
      t.integer :actual_minutes, null: false, default: 0  # Always track time, even if 0
      t.timestamps
    end
    
    # Ensure only one completion record per goal per day
    # This is crucial - prevents duplicate entries that would corrupt statistics
    add_index :goal_completions, [:goal_id, :date], 
              unique: true, 
              name: 'index_goal_completions_on_goal_and_date'
    
    # Index for finding all completions for a specific date
    # Used for daily summary views
    add_index :goal_completions, :date, 
              name: 'index_goal_completions_on_date'
    
    # Index for finding recent achievements
    # Used for streak calculations and recent progress
    add_index :goal_completions, [:achieved, :date], 
              name: 'index_goal_completions_on_achieved_and_date'
    
    # Check constraint to ensure actual_minutes is non-negative
    execute <<-SQL
      ALTER TABLE goal_completions 
      ADD CONSTRAINT non_negative_actual_minutes 
      CHECK (actual_minutes >= 0);
    SQL
    
    # Check constraint to ensure dates aren't in the future
    # We can't complete goals for days that haven't happened yet
    execute <<-SQL
      ALTER TABLE goal_completions
      ADD CONSTRAINT no_future_completions
      CHECK (date <= CURRENT_DATE);
    SQL
  end
end