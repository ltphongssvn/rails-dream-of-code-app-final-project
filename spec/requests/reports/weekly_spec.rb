# spec/requests/reports/weekly_spec.rb
require 'rails_helper'

RSpec.describe "Reports::Weekly", type: :request do
  # Set up test data with a user, categories, and goals
  let!(:user) do
    User.create!(
      email_address: 'weeklyreporter@example.com',
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

  describe "GET /reports/weekly" do
    context "when not logged in" do
      it "redirects to login page" do
        get reports_weekly_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when logged in" do
      before { login_as(user) }

      context "with no date parameter" do
        it "displays report for current week by default" do
          get reports_weekly_path
          expect(response).to have_http_status(200)

          # Should calculate week boundaries from today
          expect(assigns(:week_start)).to eq(Date.current.beginning_of_week)
          expect(assigns(:week_end)).to eq(Date.current.end_of_week)
        end
      end

      context "with specific date parameter" do
        it "displays report for the week containing the specified date" do
          # Provide a date in a different week
          target_date = Date.current - 10.days
          get reports_weekly_path, params: { date: target_date.to_s }

          expect(response).to have_http_status(200)

          # Should calculate week boundaries from the target date
          expect(assigns(:week_start)).to eq(target_date.beginning_of_week)
          expect(assigns(:week_end)).to eq(target_date.end_of_week)
        end
      end

      context "with time entries across the week" do
        let!(:week_start) { Date.current.beginning_of_week }

        before do
          # Create time entries on different days of the week
          # Monday - Work
          user.time_entries.create!(
            category: work_category,
            date: week_start,
            hour: 9,
            duration_minutes: 60,
            notes: 'Monday work'
          )

          # Tuesday - Work and Study
          user.time_entries.create!(
            category: work_category,
            date: week_start + 1.day,
            hour: 9,
            duration_minutes: 45,
            notes: 'Tuesday work'
          )
          user.time_entries.create!(
            category: study_category,
            date: week_start + 1.day,
            hour: 19,
            duration_minutes: 30,
            notes: 'Tuesday study'
          )

          # Wednesday - Study
          user.time_entries.create!(
            category: study_category,
            date: week_start + 2.days,
            hour: 14,
            duration_minutes: 60,
            notes: 'Wednesday study'
          )

          # Thursday - Work
          user.time_entries.create!(
            category: work_category,
            date: week_start + 3.days,
            hour: 10,
            duration_minutes: 50,
            notes: 'Thursday work'
          )

          # Friday, Saturday, Sunday - no entries to test sparse data
        end

        it "calculates total minutes across entire week correctly" do
          get reports_weekly_path

          # Total: 60 + 45 + 30 + 60 + 50 = 245 minutes
          expect(assigns(:total_minutes)).to eq(245)
        end

        it "calculates daily average correctly" do
          get reports_weekly_path

          # Average: 245 / 7 = 35 minutes per day (rounded)
          expect(assigns(:daily_average)).to eq(35)
        end

        it "groups time by category correctly across the week" do
          get reports_weekly_path

          time_by_category = assigns(:time_by_category)
          # Work: 60 + 45 + 50 = 155 minutes
          expect(time_by_category['Work']).to eq(155)
          # Study: 30 + 60 = 90 minutes
          expect(time_by_category['Study']).to eq(90)
        end

        it "sorts categories by time descending" do
          get reports_weekly_path

          time_by_category = assigns(:time_by_category)
          category_names = time_by_category.keys
          expect(category_names.first).to eq('Work') # Most time
          expect(category_names.last).to eq('Study') # Least time
        end

        it "groups time by date showing daily breakdown" do
          get reports_weekly_path

          time_by_date = assigns(:time_by_date)

          # Monday: 60 minutes
          expect(time_by_date[week_start]).to eq(60)
          # Tuesday: 75 minutes (45 + 30)
          expect(time_by_date[week_start + 1.day]).to eq(75)
          # Wednesday: 60 minutes
          expect(time_by_date[week_start + 2.days]).to eq(60)
          # Thursday: 50 minutes
          expect(time_by_date[week_start + 3.days]).to eq(50)
          # Friday, Saturday, Sunday should not be in the hash (no entries)
          expect(time_by_date[week_start + 4.days]).to be_nil
        end
      end

      context "with no time entries for the week" do
        it "shows zero total minutes" do
          get reports_weekly_path

          expect(assigns(:total_minutes)).to eq(0)
        end

        it "shows zero daily average" do
          get reports_weekly_path

          expect(assigns(:daily_average)).to eq(0)
        end

        it "shows empty category breakdown" do
          get reports_weekly_path

          expect(assigns(:time_by_category)).to be_empty
        end
      end

      context "with goals for the week" do
        let!(:week_start) { Date.current.beginning_of_week }

        # Daily goal applies all 7 days
        let!(:daily_work_goal) do
          user.goals.create!(
            category: work_category,
            goal_type: 'daily',
            target_minutes: 60,
            active: true
          )
        end

        context "when all goals achieved across the week" do
          before do
            # Create completions for all 7 days showing achievement
            7.times do |i|
              daily_work_goal.goal_completions.create!(
                date: week_start + i.days,
                actual_minutes: 60,
                achieved: true
              )
            end
          end

          it "counts total achieved goals correctly" do
            get reports_weekly_path

            expect(assigns(:goals_achieved_count)).to eq(7)
          end

          it "calculates achievement percentage as 100%" do
            get reports_weekly_path

            expect(assigns(:achievement_percentage)).to eq(100)
          end
        end

        context "when some goals achieved and some missed" do
          before do
            # Achieved on Monday, Tuesday, Wednesday (3 days)
            3.times do |i|
              daily_work_goal.goal_completions.create!(
                date: week_start + i.days,
                actual_minutes: 60,
                achieved: true
              )
            end

            # Missed on Thursday, Friday (2 days)
            2.times do |i|
              daily_work_goal.goal_completions.create!(
                date: week_start + 3.days + i.days,
                actual_minutes: 30,
                achieved: false
              )
            end

            # No entries for Saturday, Sunday (2 days)
          end

          it "counts achieved and missed goals correctly" do
            get reports_weekly_path

            expect(assigns(:goals_achieved_count)).to eq(3)
            expect(assigns(:goals_missed_count)).to eq(2)
          end

          it "calculates achievement percentage correctly" do
            get reports_weekly_path

            # 3 achieved out of 7 total opportunities = 43% (rounded)
            expect(assigns(:achievement_percentage)).to be_between(40, 45)
          end
        end

        context "with achievement by day breakdown" do
          before do
            # Achieve goal on Monday and Tuesday
            daily_work_goal.goal_completions.create!(
              date: week_start,
              actual_minutes: 60,
              achieved: true
            )
            daily_work_goal.goal_completions.create!(
              date: week_start + 1.day,
              actual_minutes: 60,
              achieved: true
            )

            # Miss goal on Wednesday
            daily_work_goal.goal_completions.create!(
              date: week_start + 2.days,
              actual_minutes: 30,
              achieved: false
            )
          end

          it "calculates achievement percentage for each day of week" do
            get reports_weekly_path

            achievement_by_day = assigns(:achievement_by_day)

            # Monday should be 100% (1 goal, 1 achieved)
            expect(achievement_by_day['Monday']).to eq(100)
            # Tuesday should be 100%
            expect(achievement_by_day['Tuesday']).to eq(100)
            # Wednesday should be 0% (1 goal, 0 achieved)
            expect(achievement_by_day['Wednesday']).to eq(0)
            # Other days with no completions should be 0%
            expect(achievement_by_day['Thursday']).to eq(0)
          end
        end
      end

      context "with no applicable goals for the week" do
        it "shows zero achievement percentage without error" do
          get reports_weekly_path

          # Should handle division by zero gracefully
          expect(assigns(:achievement_percentage)).to eq(0)
        end
      end

      context "filtering out other users' data" do
        let!(:other_user) do
          User.create!(
            email_address: 'otherweekly@example.com',
            password: 'password123',
            first_name: 'Other',
            last_name: 'Weekly',
            time_zone: 'Pacific Time (US & Canada)'
          )
        end

        let!(:other_category) do
          other_user.categories.create!(name: 'Other Work', color: '#CCCCCC')
        end

        before do
          # Create time entries for other user in current week
          week_start = Date.current.beginning_of_week
          other_user.time_entries.create!(
            category: other_category,
            date: week_start,
            hour: 10,
            duration_minutes: 60
          )
          other_user.time_entries.create!(
            category: other_category,
            date: week_start + 1.day,
            hour: 11,
            duration_minutes: 45
          )
        end

        it "only shows current user's time entries" do
          get reports_weekly_path

          # Should not include other user's entries
          expect(assigns(:total_minutes)).to eq(0) # No entries for current user
          expect(assigns(:time_by_category)).to be_empty
        end
      end
    end
  end
end