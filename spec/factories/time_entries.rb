FactoryBot.define do
  factory :time_entry do
    user { nil }
    category { nil }
    date { "2025-10-06" }
    hour { 1 }
    duration_minutes { 1 }
    notes { "MyText" }
  end
end
