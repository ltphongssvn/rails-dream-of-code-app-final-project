# spec/requests/reports/weekly_spec.rb
require 'rails_helper'

RSpec.describe "Reports::Weekly", type: :request do
  # Use last week for all test data to avoid future date validation issues
  # This ensures all dates are in the past and can have valid time entries
  let(:test_week_start) { 2.weeks.ago.beginning_of_week }
  let(:test_week_end) { test_week_start.end_of_week }
  
  let!(:user) do
    User.create!(
      email_address: 'weekly@example.com',
      password: 'password123',
      first_name: 'Weekly',
      last_name: 'Reporter',
      time_zone: 'Pacific Time (US & Canada)'
    )
  end
  
  let!(:work_category) do
    user.categories.create!(name: 'Work', color: '#0000FF')
  end
  
  let!(:study_category) do
    user.categories.create!(name: 'Study', color: '#00FF00')
  end
  
  def login_as(test_user)
    post session_path, params: {
      email_address: test_user.email_address,
      password: 'password123'
    }
  end
  
  describe "GET /reports/weekly" do
    context "when not logged in" do
      it "redirects to login page" do
        get reports_weekly_path
        expect(response).to redirect_to(new_session_path)
      end
    end
    
    context "when logged in" do
      before { login_as(user) }
      
      context "with time entries from last week" do
        before do
          # Create time entries for last week (all dates guaranteed to be in the past)
          user.time_entries.create!(
            category: work_category,
            date: test_week_start,
            hour: 9,
            duration_minutes: 60,
            notes: 'Monday work'
          )
          user.time_entries.create!(
            category: work_category,
            date: test_week_start + 2.days,
            hour: 10,
            duration_minutes: 45,
            notes: 'Wednesday work'
          )
          user.time_entries.create!(
            category: study_category,
            date: test_week_start + 4.days,
            hour: 14,
            duration_minutes: 30,
            notes: 'Friday study'
          )
        end
        
        it "calculates total minutes correctly" do
          get reports_weekly_path, params: { week_start: test_week_start.to_s }
          expect(response).to have_http_status(200)
          expect(assigns(:total_minutes)).to eq(135) # 60 + 45 + 30
        end
      end
    end
  end
end
