# db/migrate/20251006181652_create_time_entries.rb
class CreateTimeEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :time_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.date :date, null: false
      t.integer :hour, null: false
      t.integer :duration_minutes, null: false, default: 60
      t.text :notes
      t.timestamps
    end
    
    # Composite index for the primary query pattern: "What did user X do on date Y at hour Z?"
    # This makes historical comparisons extremely fast
    add_index :time_entries, [:user_id, :date, :hour], unique: true, 
              name: 'index_time_entries_on_user_date_hour'
    
    # Index for finding all entries on a specific date (useful for daily summaries)
    add_index :time_entries, [:user_id, :date], 
              name: 'index_time_entries_on_user_date'
    
    # Index for finding patterns at the same hour across different days
    # "What do I usually do at 9am?"
    add_index :time_entries, [:user_id, :hour], 
              name: 'index_time_entries_on_user_hour'
    
    # Check constraint to ensure hour is valid (0-23)
    # This prevents invalid hours at the database level
    execute <<-SQL
      ALTER TABLE time_entries 
      ADD CONSTRAINT valid_hour 
      CHECK (hour >= 0 AND hour <= 23);
    SQL
    
    # Check constraint to ensure duration is reasonable (1-60 minutes)
    # You can't spend 0 minutes or more than 60 minutes in an hour
    execute <<-SQL
      ALTER TABLE time_entries 
      ADD CONSTRAINT valid_duration 
      CHECK (duration_minutes >= 1 AND duration_minutes <= 60);
    SQL
    
    # Check constraint to ensure date is not in the future
    # This prevents accidental future entries (can be removed if you want to allow planning)
    execute <<-SQL
      ALTER TABLE time_entries 
      ADD CONSTRAINT no_future_entries 
      CHECK (date <= CURRENT_DATE);
    SQL
  end
end
