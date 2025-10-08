# spec/requests/reports/categories_spec.rb
require 'rails_helper'

RSpec.describe "Reports::Categories", type: :request do
  let!(:user) do
    User.create!(
      email_address: 'categoryreporter@example.com',
      password: 'password123',
      first_name: 'Category',
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

  # Create subcategory for testing hierarchical rollup
  let!(:meetings_subcategory) do
    user.categories.create!(
      name: 'Meetings',
      color: '#0088FF',
      parent_category: work_category
    )
  end

  def login_as(test_user)
    post session_path, params: {
      email_address: test_user.email_address,
      password: 'password123'
    }
  end

  describe "GET /reports/category_breakdown" do
    context "when not logged in" do
      it "redirects to login page" do
        get reports_category_breakdown_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when logged in" do
      before { login_as(user) }

      context "with no date range filter" do
        before do
          # Create entries in the past
          past_date = Date.current - 5.days

          user.time_entries.create!(
            category: work_category,
            date: past_date,
            hour: 9,
            duration_minutes: 60
          )

          user.time_entries.create!(
            category: study_category,
            date: past_date,
            hour: 14,
            duration_minutes: 30
          )
        end

        it "displays all-time category breakdown" do
          get reports_category_breakdown_path

          expect(response).to have_http_status(200)
          expect(assigns(:start_date)).to be_nil
          expect(assigns(:end_date)).to be_nil
        end

        it "calculates total minutes across all time" do
          get reports_category_breakdown_path

          expect(assigns(:total_minutes)).to eq(90)
        end

        it "groups time by category" do
          get reports_category_breakdown_path

          breakdown = assigns(:category_breakdown)

          work_entry = breakdown.find { |cb| cb[:category].id == work_category.id }
          study_entry = breakdown.find { |cb| cb[:category].id == study_category.id }

          expect(work_entry[:total_minutes]).to eq(60)
          expect(study_entry[:total_minutes]).to eq(30)
        end

        it "calculates percentages correctly" do
          get reports_category_breakdown_path

          breakdown = assigns(:category_breakdown)

          work_entry = breakdown.find { |cb| cb[:category].id == work_category.id }

          # 60 out of 90 total = 66.7%
          expect(work_entry[:percentage]).to be_within(0.5).of(66.7)
        end
      end

      context "with date range filter" do
        before do
          # Create entries on different dates
          @old_date = Date.current - 30.days
          @recent_date = Date.current - 5.days

          user.time_entries.create!(
            category: work_category,
            date: @old_date,
            hour: 9,
            duration_minutes: 60
          )

          user.time_entries.create!(
            category: work_category,
            date: @recent_date,
            hour: 10,
            duration_minutes: 45
          )
        end

        it "filters entries by date range" do
          # Only get recent entries
          get reports_category_breakdown_path, params: {
            start_date: (@recent_date - 1.day).to_s,
            end_date: (@recent_date + 1.day).to_s
          }

          expect(assigns(:total_minutes)).to eq(45)
        end
      end

      context "with hierarchical categories" do
        before do
          past_date = Date.current - 5.days

          # Direct time to Work category
          user.time_entries.create!(
            category: work_category,
            date: past_date,
            hour: 9,
            duration_minutes: 30
          )

          # Time to Meetings subcategory
          user.time_entries.create!(
            category: meetings_subcategory,
            date: past_date,
            hour: 10,
            duration_minutes: 45
          )
        end

        it "calculates total time including subcategories" do
          get reports_category_breakdown_path

          breakdown = assigns(:category_breakdown)
          work_entry = breakdown.find { |cb| cb[:category].id == work_category.id }

          # Total should include both direct (30) and subcategory (45) = 75
          expect(work_entry[:total_minutes]).to eq(75)
        end

        it "shows direct minutes separate from total" do
          get reports_category_breakdown_path

          breakdown = assigns(:category_breakdown)
          work_entry = breakdown.find { |cb| cb[:category].id == work_category.id }

          expect(work_entry[:direct_minutes]).to eq(30)
          expect(work_entry[:total_minutes]).to eq(75)
        end

        it "includes subcategory breakdown" do
          get reports_category_breakdown_path

          breakdown = assigns(:category_breakdown)
          work_entry = breakdown.find { |cb| cb[:category].id == work_category.id }

          meetings_subcat = work_entry[:subcategories].find { |sc| sc[:category].id == meetings_subcategory.id }
          expect(meetings_subcat[:direct_minutes]).to eq(45)
        end
      end

      context "with no time entries" do
        it "shows zero total minutes" do
          get reports_category_breakdown_path

          expect(assigns(:total_minutes)).to eq(0)
        end

        it "shows empty category breakdown" do
          get reports_category_breakdown_path

          expect(assigns(:category_breakdown)).to be_empty
        end
      end

      context "filtering out other users' data" do
        let!(:other_user) do
          User.create!(
            email_address: 'othercategory@example.com',
            password: 'password123',
            first_name: 'Other',
            last_name: 'Category',
            time_zone: 'Pacific Time (US & Canada)'
          )
        end

        let!(:other_category) do
          other_user.categories.create!(name: 'Other Work', color: '#CCCCCC')
        end

        before do
          past_date = Date.current - 5.days
          other_user.time_entries.create!(
            category: other_category,
            date: past_date,
            hour: 10,
            duration_minutes: 60
          )
        end

        it "only shows current user's categories" do
          get reports_category_breakdown_path

          expect(assigns(:total_minutes)).to eq(0)
          expect(assigns(:category_breakdown)).to be_empty
        end
      end
    end
  end
end