# spec/factories/categories.rb
FactoryBot.define do
  factory :category do
    # Associate with a user - using association helper
    association :user

    # Generate unique names to avoid conflicts in tests
    sequence(:name) { |n| "Category #{n}" }

    # Provide a valid hex color code
    color { "#%06x" % (rand * 0xffffff) }

    # Parent category is optional, defaults to nil for top-level categories
    parent_category { nil }

    # Trait for creating subcategories easily in tests
    trait :with_parent do
      association :parent_category, factory: :category
    end

    # Trait for categories without a color (to test default assignment)
    trait :without_color do
      color { nil }
    end

    # Trait for creating a category with specific attributes
    trait :work do
      name { "Work" }
      color { "#0000FF" }
    end

    trait :exercise do
      name { "Exercise" }
      color { "#FF0000" }
    end
  end
end