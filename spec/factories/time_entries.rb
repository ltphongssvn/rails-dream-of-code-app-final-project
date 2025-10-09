# spec/factories/time_entries.rb
FactoryBot.define do
  factory :time_entry do
    # Use associations to automatically create user and category if not provided
    association :user
    association :category
    
    # Use dynamic date - defaults to today but can be overridden
    date { Date.current }
    
    # Use sequence for hour to avoid conflicts when creating multiple entries
    # This cycles through hours 0-23 to minimize conflicts
    sequence(:hour) { |n| n % 24 }
    
    # Default to a full hour, but can be overridden
    duration_minutes { 60 }
    
    # Optional notes field with more realistic default
    notes { "Time tracking entry" }
    
    # Trait for morning entries (6-11 AM)
    trait :morning do
      hour { rand(6..11) }
    end
    
    # Trait for afternoon entries (12-17 PM)
    trait :afternoon do
      hour { rand(12..17) }
    end
    
    # Trait for evening entries (18-23 PM)
    trait :evening do
      hour { rand(18..23) }
    end
    
    # Trait for partial hour entries
    trait :partial do
      duration_minutes { rand(15..45) }
    end
    
    # Trait for yesterday's entries
    trait :yesterday do
      date { Date.yesterday }
    end
    
    # Trait for last week's entries
    trait :last_week do
      date { 1.week.ago }
    end
  end
end