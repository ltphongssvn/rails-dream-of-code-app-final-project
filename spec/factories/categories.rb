FactoryBot.define do
  factory :category do
    user { nil }
    name { "MyString" }
    color { "MyString" }
    parent_category { nil }
  end
end
