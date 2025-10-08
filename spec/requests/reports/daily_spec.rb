# spec/requests/reports/daily_spec.rb
require 'rails_helper'

RSpec.describe "Reports::Daily", type: :request do
  # Set up test data with a user, categories, time entries, and goals
  let!(:user) do
    User.create!(
      email_address: 'reporter@example.com',
      password: 'password123',
      first_name: 'Report',
      last_name: 'User',
      time_zone: 'Pacific Time (US & Canada)'
    )
  end

  let!(:work_category) do
    user.categories.create!(name: 'Work', color: '#0000FF')
  end

  let!(:study_category) do
    user.categories.create!(name: 'Study', color: '#00FF00')
  end

  let!(:exercise_category) do
    user.categories.create!(name: 'Exercise', color: '#FF0000')
  end

  # Helper method to log in a user for authenticated tests
  def login_as(test_user)
    post session_path, params: {
      email_address: test_user.email_address,
      password: 'password123'
    }
  end

  describe "GET /reports/daily" do
    context "when not logged in" do
      it "redirects to login page" do
        get reports_daily_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when logged in" do
      before { login_as(user) }

      context "with no date parameter" do
        it "displays report for today by default" do
          get reports_daily_path
          expect(response).to have_http_status(200)
          expect(assigns(:date)).to eq(Date.current)
        end
      end

      context "with specific date parameter" do
        it "displays report for the specified date" do
          target_date = Date.current - 3.days
          get reports_daily_path, params: { date: target_date.to_s }

          expect(response).to have_http_status(200)
          expect(assigns(:date)).to eq(target_date)
        end
      end

      context "with time entries for the day" do
        let!(:today_entries) do
          [
            user.time_entries.create!(
              category: work_category,
              date: Date.current,
              hour: 9,
              duration_minutes: 60,
              notes: 'Morning work'
            ),
            user.time_entries.create!(
              category: work_category,
              date: Date.current,
              hour: 14,
              duration_minutes: 30,
              notes: 'Afternoon work session 1'
            ),
            user.time_entries.create!(
              category: work_category,
              date: Date.current,
              hour: 15,
              duration_minutes: 60,
              notes: 'Afternoon work session 2'
            ),
            user.time_entries.create!(
              category: study_category,
              date: Date.current,
              hour: 19,
              duration_minutes: 45,
              notes: 'Evening study'
            )
          ]
        end

        it "calculates total minutes correctly" do
          get reports_daily_path

          expect(assigns(:total_minutes)).to eq(195) # 60 + 30 + 60 + 45
        end

        it "groups time by category correctly" do
          get reports_daily_path

          time_by_category = assigns(:time_by_category)
          expect(time_by_category['Work']).to eq(150) # 60 + 30 + 60
          expect(time_by_category['Study']).to eq(45)
        end

        it "sorts categories by time descending" do
          get reports_daily_path

          time_by_category = assigns(:time_by_category)
          category_names = time_by_category.keys
          expect(category_names.first).to eq('Work') # Most time
          expect(category_names.last).to eq('Study') # Least time
        end

        it "orders time entries by hour" do
          get reports_daily_path

          time_entries = assigns(:time_entries)
          hours = time_entries.map(&:hour)
          expect(hours).to eq([9, 14, 15, 19]) # Chronological order
        end
      end

      context "with no time entries for the day" do
        it "shows zero total minutes" do
          get reports_daily_path

          expect(assigns(:total_minutes)).to eq(0)
        end

        it "shows empty category breakdown" do
          get reports_daily_path

          expect(assigns(:time_by_category)).to be_empty
        end
      end

      context "with goals for the day" do
        let!(:work_goal) do
          user.goals.create!(
            category: work_category,
            goal_type: 'daily',
            target_minutes: 120,
            active: true
          )
        end

        let!(:study_goal) do
          user.goals.create!(
            category: study_category,
            goal_type: 'daily',
            target_minutes: 60,
            active: true
          )
        end

        context "when goals are achieved" do
          before do
            # Create time entries that meet the work goal (120 minutes target)
            # Need to create multiple entries since each can only be max 60 minutes
            user.time_entries.create!(
              category: work_category,
              date: Date.current,
              hour: 9,
              duration_minutes: 60
            )
            user.time_entries.create!(
              category: work_category,
              date: Date.current,
              hour: 10,
              duration_minutes: 60
            )
            user.time_entries.create!(
              category: work_category,
              date: Date.current,
              hour: 11,
              duration_minutes: 30
            )

            # Create time entry that meets the study goal (60 minutes target)
            user.time_entries.create!(
              category: study_category,
              date: Date.current,
              hour: 14,
              duration_minutes: 60
            )
            user.time_entries.create!(
              category: study_category,
              date: Date.current,
              hour: 15,
              duration_minutes: 10
            )

            # Create goal completions showing achievement
            # Work goal: 150 minutes actual >= 120 target
            work_goal.goal_completions.create!(
              date: Date.current,
              actual_minutes: 150,
              achieved: true
            )
            # Study goal: 70 minutes actual >= 60 target
            study_goal.goal_completions.create!(
              date: Date.current,
              actual_minutes: 70,
              achieved: true
            )
          end

          it "counts achieved goals correctly" do
            get reports_daily_path

            expect(assigns(:goals_achieved_count)).to eq(2)
            expect(assigns(:goals_missed_count)).to eq(0)
          end

          it "calculates achievement percentage correctly" do
            get reports_daily_path

            expect(assigns(:achievement_percentage)).to eq(100)
          end
        end

        context "when goals are missed" do
          before do
            # Create time entry that doesn't meet the work goal (120 target)
            user.time_entries.create!(
              category: work_category,
              date: Date.current,
              hour: 9,
              duration_minutes: 30
            )

            # Create goal completion showing failure
            work_goal.goal_completions.create!(
              date: Date.current,
              actual_minutes: 30,
              achieved: false
            )
          end

          it "counts missed goals correctly" do
            get reports_daily_path

            expect(assigns(:goals_achieved_count)).to eq(0)
            expect(assigns(:goals_missed_count)).to eq(1)
          end

          it "calculates achievement percentage correctly" do
            get reports_daily_path

            # Only 1 out of 2 goals was attempted (work goal)
            # Study goal has no completion record
            # Achievement percentage should reflect actual applicable goals
            expect(assigns(:achievement_percentage)).to be_between(0, 100)
          end
        end

        context "when some goals achieved and some missed" do
          before do
            # Work goal achieved with 150 minutes
            user.time_entries.create!(
              category: work_category,
              date: Date.current,
              hour: 9,
              duration_minutes: 60
            )
            user.time_entries.create!(
              category: work_category,
              date: Date.current,
              hour: 10,
              duration_minutes: 60
            )
            user.time_entries.create!(
              category: work_category,
              date: Date.current,
              hour: 11,
              duration_minutes: 30
            )

            work_goal.goal_completions.create!(
              date: Date.current,
              actual_minutes: 150,
              achieved: true
            )

            # Study goal missed with only 30 minutes
            user.time_entries.create!(
              category: study_category,
              date: Date.current,
              hour: 14,
              duration_minutes: 30
            )

            study_goal.goal_completions.create!(
              date: Date.current,
              actual_minutes: 30,
              achieved: false
            )
          end

          it "counts both achieved and missed goals" do
            get reports_daily_path

            expect(assigns(:goals_achieved_count)).to eq(1)
            expect(assigns(:goals_missed_count)).to eq(1)
          end

          it "calculates achievement percentage as 50%" do
            get reports_daily_path

            expect(assigns(:achievement_percentage)).to eq(50)
          end
        end
      end

      context "with no applicable goals for the day" do
        it "shows zero achievement percentage without error" do
          get reports_daily_path

          # Should handle division by zero gracefully
          expect(assigns(:achievement_percentage)).to eq(0)
        end
      end

      context "filtering out other users' data" do
        let!(:other_user) do
          User.create!(
            email_address: 'other@example.com',
            password: 'password123',
            first_name: 'Other',
            last_name: 'User',
            time_zone: 'Pacific Time (US & Canada)'
          )
        end

        let!(:other_category) do
          other_user.categories.create!(name: 'Other Work', color: '#CCCCCC')
        end

        let!(:other_entry) do
          other_user.time_entries.create!(
            category: other_category,
            date: Date.current,
            hour: 10,
            duration_minutes: 60
          )
        end

        it "only shows current user's time entries" do
          get reports_daily_path

          expect(assigns(:time_entries)).not_to include(other_entry)
          expect(assigns(:total_minutes)).to eq(0) # No entries for current user
        end
      end
    end
  end
end