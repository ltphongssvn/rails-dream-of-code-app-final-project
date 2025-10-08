# spec/requests/reports/monthly_debug_spec.rb
require 'rails_helper'

RSpec.describe "Reports::Monthly Debug", type: :request do
  let!(:user) do
    User.create!(
      email_address: 'monthlydebug@example.com',
      password: 'password123',
      first_name: 'Monthly',
      last_name: 'Debug',
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

  describe "GET /reports/monthly time_by_date debugging" do
    before { login_as(user) }

    it "debugs the time_by_date hash structure" do
      month_start = Date.current.beginning_of_month

      puts "\n=== DEBUG: Creating time entries ==="
      entry1 = user.time_entries.create!(
        category: work_category,
        date: month_start,
        hour: 9,
        duration_minutes: 60
      )
      puts "Entry 1 date: #{entry1.date.inspect} (class: #{entry1.date.class})"

      entry2 = user.time_entries.create!(
        category: work_category,
        date: month_start + 5.days,
        hour: 10,
        duration_minutes: 45
      )
      puts "Entry 2 date: #{entry2.date.inspect} (class: #{entry2.date.class})"

      puts "\n=== DEBUG: Test variable month_start ==="
      puts "month_start: #{month_start.inspect} (class: #{month_start.class})"

      get reports_monthly_path

      time_by_date = assigns(:time_by_date)

      puts "\n=== DEBUG: time_by_date hash ==="
      puts "time_by_date class: #{time_by_date.class}"
      puts "time_by_date size: #{time_by_date.size}"
      puts "time_by_date contents:"
      time_by_date.each do |date, minutes|
        puts "  Key: #{date.inspect} (class: #{date.class}) => Value: #{minutes}"
      end

      puts "\n=== DEBUG: Attempting hash access ==="
      puts "month_start key: #{month_start.inspect}"
      puts "Result of time_by_date[month_start]: #{time_by_date[month_start].inspect}"

      puts "\n=== DEBUG: Checking key equality ==="
      first_key = time_by_date.keys.first
      puts "First key in hash: #{first_key.inspect}"
      puts "month_start == first_key: #{month_start == first_key}"
      puts "month_start.class: #{month_start.class}"
      puts "first_key.class: #{first_key.class}"

      # This will show us what's really happening
      expect(time_by_date.size).to eq(2)
    end
  end
end