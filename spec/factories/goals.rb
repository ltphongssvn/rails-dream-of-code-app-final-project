# spec/factories/goals.rb
FactoryBot.define do
  factory :goal do
    # Associate with a user - goals must belong to someone
    association :user

    # Category is optional - goals can be general or category-specific
    category { nil }

    # Default to 'daily' goal type - one of the valid GOAL_TYPES
    goal_type { 'daily' }

    # Reasonable default target of 30 minutes
    target_minutes { 30 }

    # Hour is only needed for specific_hour goals, so default to nil
    hour { nil }

    # Set days_array directly - this is what the model expects
    # The model will convert this to JSON for days_of_week during save
    days_array { ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'] }

    # Goals should be active by default
    active { true }

    # Trait for weekly goals
    trait :weekly do
      goal_type { 'weekly' }
      target_minutes { 300 } # 5 hours per week
      days_array { [] } # Weekly goals don't need specific days
    end

    # Trait for specific hour goals (like "exercise at 7 AM")
    trait :specific_hour do
      goal_type { 'specific_hour' }
      hour { 7 }
      target_minutes { 60 }
    end

    # Trait for goals with a category
    trait :with_category do
      association :category
    end

    # Trait for inactive/archived goals
    trait :inactive do
      active { false }
    end

    # Trait for weekend goals
    trait :weekend do
      days_array { ['Saturday', 'Sunday'] }
    end
  end
end