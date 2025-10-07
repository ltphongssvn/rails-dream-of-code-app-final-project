# spec/factories/goal_completions.rb
FactoryBot.define do
  factory :goal_completion do
    # Association with goal - this will automatically create a goal if one isn't provided
    association :goal

    # Default to today's date, but can be overridden in tests
    date { Date.current }

    # Default to not achieved, but tests can override this
    achieved { false }

    # Default to 0 minutes, representing no progress
    actual_minutes { 0 }

    # Trait for a successful completion
    trait :achieved do
      achieved { true }
      # When achieved, set actual_minutes to match the goal's target
      after(:build) do |completion|
        completion.actual_minutes = completion.goal.target_minutes if completion.goal
      end
    end

    # Trait for a partial completion
    trait :partial do
      achieved { false }
      # Set to half of the target minutes
      after(:build) do |completion|
        completion.actual_minutes = (completion.goal.target_minutes / 2) if completion.goal
      end
    end

    # Trait for yesterday's completion
    trait :yesterday do
      date { Date.yesterday }
    end

    # Trait for last week's completion
    trait :last_week do
      date { 1.week.ago.to_date }
    end

    # Factory variant for creating achieved completions directly
    factory :achieved_goal_completion do
      achieved { true }
      after(:build) do |completion|
        completion.actual_minutes = completion.goal.target_minutes if completion.goal
      end
    end

    # Factory variant for creating missed completions
    factory :missed_goal_completion do
      achieved { false }
      actual_minutes { 10 }  # Some effort, but not enough
    end
  end
end