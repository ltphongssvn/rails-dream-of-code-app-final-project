# spec/requests/goals_spec.rb
require 'rails_helper'

RSpec.describe "Goals", type: :request do
  let!(:user) { create(:user) }
  let!(:other_user) { create(:user) }
  let!(:category) { create(:category, user: user, name: "Study") }

  # Helper method to log in a user
  def login_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: 'SecurePassword123!'
    }
  end

  describe "GET /goals" do
    context "when not logged in" do
      it "redirects to login page" do
        get goals_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when logged in" do
      before { login_as(user) }

      it "displays the user's active goals" do
        active_goal = create(:goal, user: user, target_minutes: 90, active: true)
        inactive_goal = create(:goal, user: user, target_minutes: 120, active: false)

        get goals_path
        expect(response).to have_http_status(200)
        expect(response.body).to include("90")
      end

      it "does not display other users' goals" do
        user_goal = create(:goal, user: user, target_minutes: 60)
        other_goal = create(:goal, user: other_user, target_minutes: 45)

        get goals_path
        expect(response.body).to include("60")
        expect(response.body).not_to include("45")
      end
    end
  end

  describe "GET /goals/:id" do
    context "when logged in" do
      before { login_as(user) }

      it "shows the goal details" do
        goal = create(:goal, user: user, target_minutes: 60)

        get goal_path(goal)
        expect(response).to have_http_status(200)
        expect(response.body).to include("60")
      end

      it "prevents viewing other users' goals" do
        other_goal = create(:goal, user: other_user)

        get goal_path(other_goal)
        expect(response).to redirect_to(goals_path)
        follow_redirect!
        expect(response.body).to include("Goal not found")
      end

      it "displays completion statistics" do
        goal = create(:goal, user: user, target_minutes: 60)
        create(:goal_completion, goal: goal, date: Date.current, actual_minutes: 60, achieved: true)

        get goal_path(goal)
        expect(response).to have_http_status(200)
      end
    end
  end

  describe "GET /goals/new" do
    context "when not logged in" do
      it "redirects to login page" do
        get new_goal_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when logged in" do
      before { login_as(user) }

      it "displays the new goal form" do
        get new_goal_path
        expect(response).to have_http_status(200)
        expect(response.body).to include("target_minutes")
        expect(response.body).to include("goal_type")
      end
    end
  end

  describe "POST /goals" do
    context "when logged in" do
      before { login_as(user) }

      it "creates a new daily goal with valid parameters" do
        expect {
          post goals_path, params: {
            goal: {
              goal_type: "daily",
              target_minutes: 60,
              category_id: category.id
            }
          }
        }.to change(user.goals, :count).by(1)

        expect(response).to redirect_to(goals_path)
        follow_redirect!
        expect(response.body).to include("Goal was successfully created")
      end

      it "creates a specific_hour goal with hour parameter" do
        post goals_path, params: {
          goal: {
            goal_type: "specific_hour",
            target_minutes: 30,
            hour: 9,
            category_id: category.id
          }
        }

        new_goal = Goal.last
        expect(new_goal.hour).to eq(9)
        expect(new_goal.goal_type).to eq("specific_hour")
      end

      it "creates a goal with specific days of week" do
        post goals_path, params: {
          goal: {
            goal_type: "daily",
            target_minutes: 45,
            category_id: category.id,
            days_array: ["", "Monday", "Wednesday", "Friday"]
          }
        }

        new_goal = Goal.last
        expect(new_goal.days_array).to match_array(["Monday", "Wednesday", "Friday"])
      end

      it "does not create goal with invalid parameters" do
        expect {
          post goals_path, params: {
            goal: {
              goal_type: "daily",
              target_minutes: -10  # Invalid: negative minutes
            }
          }
        }.not_to change(Goal, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "creates a goal without category (general goal)" do
        expect {
          post goals_path, params: {
            goal: {
              goal_type: "daily",
              target_minutes: 120
            }
          }
        }.to change(user.goals, :count).by(1)

        new_goal = Goal.last
        expect(new_goal.category).to be_nil
      end
    end
  end

  describe "GET /goals/:id/edit" do
    context "when logged in" do
      before { login_as(user) }

      it "displays the edit form for user's goal" do
        goal = create(:goal, user: user, target_minutes: 60)

        get edit_goal_path(goal)
        expect(response).to have_http_status(200)
        expect(response.body).to include("60")
      end

      it "prevents editing other users' goals" do
        other_goal = create(:goal, user: other_user)

        get edit_goal_path(other_goal)
        expect(response).to redirect_to(goals_path)
        follow_redirect!
        expect(response.body).to include("Goal not found")
      end
    end
  end

  describe "PATCH /goals/:id" do
    context "when logged in" do
      before { login_as(user) }

      it "updates the goal with valid parameters" do
        goal = create(:goal, user: user, target_minutes: 60)

        patch goal_path(goal), params: {
          goal: {
            target_minutes: 90
          }
        }

        goal.reload
        expect(goal.target_minutes).to eq(90)
        expect(response).to redirect_to(goal_path(goal))
      end

      it "updates days_of_week array" do
        goal = create(:goal, user: user, target_minutes: 60)

        patch goal_path(goal), params: {
          goal: {
            target_minutes: 60,
            days_array: ["Monday", "Tuesday"]
          }
        }

        goal.reload
        expect(goal.days_array).to match_array(["Monday", "Tuesday"])
      end

      it "does not update with invalid parameters" do
        goal = create(:goal, user: user, target_minutes: 60)

        patch goal_path(goal), params: {
          goal: {
            target_minutes: 0  # Invalid
          }
        }

        goal.reload
        expect(goal.target_minutes).to eq(60)  # Should not change
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "prevents updating other users' goals" do
        other_goal = create(:goal, user: other_user, target_minutes: 60)

        patch goal_path(other_goal), params: {
          goal: { target_minutes: 120 }
        }

        other_goal.reload
        expect(other_goal.target_minutes).to eq(60)  # Should not change
        expect(response).to redirect_to(goals_path)
      end
    end
  end

  describe "DELETE /goals/:id" do
    context "when logged in" do
      before { login_as(user) }

      it "deletes the goal" do
        goal = create(:goal, user: user)

        expect {
          delete goal_path(goal)
        }.to change(user.goals, :count).by(-1)

        expect(response).to redirect_to(goals_path)
        follow_redirect!
        expect(response.body).to include("successfully deleted")
      end

      it "deletes associated goal completions" do
        goal = create(:goal, user: user)
        create(:goal_completion, goal: goal, date: Date.current)

        expect {
          delete goal_path(goal)
        }.to change(GoalCompletion, :count).by(-1)
      end

      it "prevents deleting other users' goals" do
        other_goal = create(:goal, user: other_user)

        expect {
          delete goal_path(other_goal)
        }.not_to change(Goal, :count)

        expect(response).to redirect_to(goals_path)
      end
    end
  end
end