# spec/requests/reports/monthly_spec.rb
require 'rails_helper'

RSpec.describe "Reports::Monthly", type: :request do
  let!(:user) do
    User.create!(
      email_address: 'monthlyreporter@example.com',
      password: 'password123',
      first_name: 'Monthly',
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

  describe "GET /reports/monthly" do
    context "when not logged in" do
      it "redirects to login page" do
        get reports_monthly_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when logged in" do
      before { login_as(user) }

      context "with no date parameter" do
        it "displays report for current month by default" do
          get reports_monthly_path
          expect(response).to have_http_status(200)

          expect(assigns(:month_start)).to eq(Date.current.beginning_of_month)
          expect(assigns(:month_end)).to eq(Date.current.end_of_month)
        end
      end

      context "with specific date parameter" do
        it "displays report for the month containing the specified date" do
          target_date = Date.current - 60.days
          get reports_monthly_path, params: { date: target_date.to_s }

          expect(response).to have_http_status(200)
          expect(assigns(:month_start)).to eq(target_date.beginning_of_month)
          expect(assigns(:month_end)).to eq(target_date.end_of_month)
        end
      end

      context "with time entries across the month" do
        before do
          @month_start = (Date.current - 1.month).beginning_of_month

          user.time_entries.create!(
            category: work_category,
            date: @month_start,
            hour: 9,
            duration_minutes: 60
          )

          user.time_entries.create!(
            category: work_category,
            date: @month_start + 5.days,
            hour: 10,
            duration_minutes: 45
          )

          user.time_entries.create!(
            category: study_category,
            date: @month_start + 10.days,
            hour: 14,
            duration_minutes: 30
          )

          user.time_entries.create!(
            category: work_category,
            date: @month_start + 15.days,
            hour: 11,
            duration_minutes: 50
          )

          user.time_entries.create!(
            category: study_category,
            date: @month_start + 20.days,
            hour: 19,
            duration_minutes: 40
          )
        end

        it "calculates total minutes across entire month correctly" do
          get reports_monthly_path, params: { date: @month_start.to_s }

          expect(assigns(:total_minutes)).to eq(225)
        end

        it "calculates daily average based on actual month length" do
          get reports_monthly_path, params: { date: @month_start.to_s }

          days_in_month = assigns(:days_in_month)
          daily_average = assigns(:daily_average)

          expected_average = (225.0 / days_in_month).round
          expect(daily_average).to eq(expected_average)
        end

        it "groups time by category correctly across the month" do
          get reports_monthly_path, params: { date: @month_start.to_s }

          time_by_category = assigns(:time_by_category)
          expect(time_by_category['Work']).to eq(155)
          expect(time_by_category['Study']).to eq(70)
        end

        it "provides time by date breakdown" do
          get reports_monthly_path, params: { date: @month_start.to_s }

          time_by_date = assigns(:time_by_date)

          expect(time_by_date[@month_start]).to eq(60)
          expect(time_by_date[@month_start + 5.days]).to eq(45)
          expect(time_by_date[@month_start + 10.days]).to eq(30)
        end
      end

      context "with no time entries for the month" do
        it "shows zero total minutes" do
          get reports_monthly_path

          expect(assigns(:total_minutes)).to eq(0)
          expect(assigns(:daily_average)).to eq(0)
        end

        it "shows empty category breakdown" do
          get reports_monthly_path

          expect(assigns(:time_by_category)).to be_empty
        end
      end

      context "with goals for the month" do
        before do
          @month_start = (Date.current - 1.month).beginning_of_month
        end

        let!(:daily_goal) do
          user.goals.create!(
            category: work_category,
            goal_type: 'daily',
            target_minutes: 60,
            active: true
          )
        end

        context "when some goals achieved" do
          before do
            5.times do |i|
              daily_goal.goal_completions.create!(
                date: @month_start + i.days,
                actual_minutes: 60,
                achieved: true
              )
            end

            3.times do |i|
              daily_goal.goal_completions.create!(
                date: @month_start + 5.days + i.days,
                actual_minutes: 30,
                achieved: false
              )
            end
          end

          it "counts achieved and missed goals correctly" do
            get reports_monthly_path, params: { date: @month_start.to_s }

            expect(assigns(:goals_achieved_count)).to eq(5)
            expect(assigns(:goals_missed_count)).to eq(3)
          end

          it "calculates achievement percentage correctly" do
            get reports_monthly_path, params: { date: @month_start.to_s }

            expect(assigns(:achievement_percentage)).to be_between(0, 100)
          end
        end
      end

      context "with no applicable goals for the month" do
        it "shows zero achievement percentage without error" do
          get reports_monthly_path

          expect(assigns(:achievement_percentage)).to eq(0)
        end
      end

      context "filtering out other users' data" do
        let!(:other_user) do
          User.create!(
            email_address: 'othermonthly@example.com',
            password: 'password123',
            first_name: 'Other',
            last_name: 'Monthly',
            time_zone: 'Pacific Time (US & Canada)'
          )
        end

        let!(:other_category) do
          other_user.categories.create!(name: 'Other Work', color: '#CCCCCC')
        end

        before do
          month_start = (Date.current - 1.month).beginning_of_month
          other_user.time_entries.create!(
            category: other_category,
            date: month_start,
            hour: 10,
            duration_minutes: 60
          )
        end

        it "only shows current user's time entries" do
          get reports_monthly_path

          expect(assigns(:total_minutes)).to eq(0)
          expect(assigns(:time_by_category)).to be_empty
        end
      end
    end
  end
end