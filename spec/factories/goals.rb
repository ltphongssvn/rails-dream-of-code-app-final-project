FactoryBot.define do
  factory :goal do
    user { nil }
    category { nil }
    goal_type { "MyString" }
    target_minutes { 1 }
    hour { 1 }
    days_of_week { "MyString" }
    active { false }
  end
end
