# spec/factories/sessions.rb
FactoryBot.define do
  factory :session do
    association :user
    ip_address { "127.0.0.1" }
    user_agent { "Mozilla/5.0 (RSpec Test Suite)" }
    
    # Trait for sessions from different IP addresses
    trait :remote do
      ip_address { "192.168.1.100" }
    end
    
    # Trait for mobile sessions
    trait :mobile do
      user_agent { "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)" }
    end
  end
end
