# spec/requests/reports/daily_debug_spec.rb
require 'rails_helper'

RSpec.describe "Reports::Daily Debug", type: :request do
  let!(:user) do
    User.create!(
      email_address: 'debug@example.com',
      password: 'password123',
      first_name: 'Debug',
      last_name: 'User',
      time_zone: 'Pacific Time (US & Canada)'
    )
  end
  
  let!(:work_category) do
    user.categories.create!(name: 'Work', color: '#0000FF')
  end
  
  def login_as(test_user)
    post session_path, params: {
      email_address: test_user.email_address,
      password: 'password123'
    }
  end
  
  describe "GET /reports/daily debugging" do
    before { login_as(user) }
    
    it "debugs the basic request" do
      puts "\n" + "="*80
      puts "DEBUG TEST: Making basic request without parameters"
      
      get reports_daily_path
      
      puts "Response status: #{response.status}"
      puts "Response content type: #{response.content_type}"
      puts "Response headers: #{response.headers.select { |k,v| k.include?('Content') }}"
      puts "Response body first 200 chars: #{response.body[0..200]}" if response.body
      puts "="*80 + "\n"
      
      expect(response).to have_http_status(200)
    end
    
    it "debugs request with specific date" do
      puts "\n" + "="*80
      puts "DEBUG TEST: Making request with specific date parameter"
      
      target_date = Date.current - 3.days
      get reports_daily_path, params: { date: target_date.to_s }
      
      puts "Response status: #{response.status}"
      puts "Response content type: #{response.content_type}"
      puts "Assigns available: #{respond_to?(:assigns)}"
      
      if respond_to?(:assigns)
        puts "@date value: #{assigns(:date)}"
        puts "@time_by_category type: #{assigns(:time_by_category).class}"
        puts "@time_by_category value: #{assigns(:time_by_category).inspect}"
      end
      puts "="*80 + "\n"
      
      expect(response).to have_http_status(200)
    end
    
    it "debugs the data structure issue" do
      puts "\n" + "="*80
      puts "DEBUG TEST: Testing time_by_category data structure"
      
      # Create test data
      user.time_entries.create!(
        category: work_category,
        date: Date.current,
        hour: 9,
        duration_minutes: 60,
        notes: 'Test work'
      )
      
      get reports_daily_path
      
      puts "Response status: #{response.status}"
      
      if response.status == 200 && respond_to?(:assigns)
        time_by_category = assigns(:time_by_category)
        puts "@time_by_category class: #{time_by_category.class}"
        puts "@time_by_category inspect: #{time_by_category.inspect}"
        
        if time_by_category.is_a?(Array)
          puts "It's an array! Trying to access as array:"
          puts "First element: #{time_by_category[0].inspect}" if time_by_category[0]
        elsif time_by_category.is_a?(Hash)
          puts "It's a hash! Trying to access with key:"
          puts "Work value: #{time_by_category['Work']}"
        else
          puts "Unknown type!"
        end
      end
      puts "="*80 + "\n"
    end
  end
end
