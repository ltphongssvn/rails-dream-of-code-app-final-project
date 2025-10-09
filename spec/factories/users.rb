# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "SecurePassword123!" }
    password_confirmation { "SecurePassword123!" }
    first_name { "John" }
    last_name { "Doe" }
    time_zone { "Pacific Time (US & Canada)" }

    # Trait for creating users with different attributes easily
    trait :with_eastern_timezone do
      time_zone { "Eastern Time (US & Canada)" }
    end

    trait :admin do
      first_name { "Admin" }
      last_name { "User" }
    end

    # Trait for creating a user with associated data
    trait :with_categories do
      after(:create) do |user|
        create_list(:category, 3, user: user)
      end
    end

    trait :with_time_entries do
      after(:create) do |user|
        category = create(:category, user: user)
        create_list(:time_entry, 5, user: user, category: category)
      end
    end
  end
end