# spec/requests/goal_completions_spec.rb
require 'rails_helper'

RSpec.describe "GoalCompletions", type: :request do
  # Set up test data with a user, a goal, and necessary associations
  let!(:user) do
    User.create!(
      email_address: 'goaluser@example.com',
      password: 'password123',
      first_name: 'Goal',
      last_name: 'User',
      time_zone: 'Pacific Time (US & Canada)'
    )
  end

  let!(:other_user) do
    User.create!(
      email_address: 'other@example.com',
      password: 'password123',
      first_name: 'Other',
      last_name: 'User',
      time_zone: 'Pacific Time (US & Canada)'
    )
  end

  let!(:goal) do
    user.goals.create!(
      goal_type: 'daily',
      target_minutes: 60,
      active: true
    )
  end

  let!(:other_goal) do
    other_user.goals.create!(
      goal_type: 'daily',
      target_minutes: 60,
      active: true
    )
  end

  # Helper method to log in a user for authenticated tests
  def login_as(test_user)
    post session_path, params: {
      email_address: test_user.email_address,
      password: 'password123'
    }
  end

  describe "POST /goals/:goal_id/goal_completions" do
    context "when logged in" do
      before { login_as(user) }

      context "with valid parameters" do
        let(:valid_params) do
          {
            goal_completion: {
              date: Date.current,
              actual_minutes: 75
            }
          }
        end

        it "creates a new goal completion record" do
          expect {
            post goal_goal_completions_path(goal), params: valid_params
          }.to change(GoalCompletion, :count).by(1)

          completion = GoalCompletion.last
          expect(completion.goal).to eq(goal)
          expect(completion.date).to eq(Date.current)
          expect(completion.actual_minutes).to eq(75)
        end

        it "automatically calculates achievement status" do
          # Goal target is 60 minutes, we're logging 75 minutes
          post goal_goal_completions_path(goal), params: valid_params

          completion = GoalCompletion.last
          # The model's before_validation callback should have set achieved to true
          # because 75 >= 60 (actual >= target)
          expect(completion.achieved).to eq(true)
        end

        it "creates an unachieved completion when actual minutes is below target" do
          post goal_goal_completions_path(goal), params: {
            goal_completion: {
              date: Date.current,
              actual_minutes: 30
            }
          }

          completion = GoalCompletion.last
          # 30 < 60, so achieved should be false
          expect(completion.achieved).to eq(false)
          expect(completion.actual_minutes).to eq(30)
        end

        it "updates existing completion instead of creating duplicate" do
          # Create an initial completion for today
          existing_completion = goal.goal_completions.create!(
            date: Date.current,
            actual_minutes: 20
          )

          # Attempt to create another completion for the same date
          # The controller uses find_or_initialize_by which should update the existing record
          expect {
            post goal_goal_completions_path(goal), params: {
              goal_completion: {
                date: Date.current,
                actual_minutes: 40
              }
            }
          }.not_to change(GoalCompletion, :count)

          # The existing completion should have been updated
          existing_completion.reload
          expect(existing_completion.actual_minutes).to eq(40)
        end

        it "redirects to the goal page with success message" do
          post goal_goal_completions_path(goal), params: valid_params

          expect(response).to redirect_to(goal_path(goal))
          follow_redirect!
          expect(response.body).to include('Goal completion recorded')
        end
      end

      context "with invalid parameters" do
        it "does not create completion with negative minutes" do
          expect {
            post goal_goal_completions_path(goal), params: {
              goal_completion: {
                date: Date.current,
                actual_minutes: -10
              }
            }
          }.not_to change(GoalCompletion, :count)

          expect(response).to redirect_to(goal_path(goal))
          follow_redirect!
          expect(response.body).to include('Unable to record completion')
        end

        it "does not create completion with minutes exceeding daily maximum" do
          expect {
            post goal_goal_completions_path(goal), params: {
              goal_completion: {
                date: Date.current,
                actual_minutes: 1500  # More than 1440 minutes in a day
              }
            }
          }.not_to change(GoalCompletion, :count)

          expect(response).to redirect_to(goal_path(goal))
          follow_redirect!
          expect(response.body).to include('Unable to record completion')
        end

        it "does not create completion without a date" do
          expect {
            post goal_goal_completions_path(goal), params: {
              goal_completion: {
                actual_minutes: 60
              }
            }
          }.not_to change(GoalCompletion, :count)
        end
      end

      context "authorization" do
        it "prevents creating completions for other users' goals" do
          # Logged in as user, trying to create completion for other_goal which belongs to other_user
          expect {
            post goal_goal_completions_path(other_goal), params: {
              goal_completion: {
                date: Date.current,
                actual_minutes: 60
              }
            }
          }.not_to change(GoalCompletion, :count)

          expect(response).to redirect_to(goals_path)
          follow_redirect!
          expect(response.body).to include('Goal not found or access denied')
        end
      end
    end

    context "when not logged in" do
      it "redirects to login page" do
        post goal_goal_completions_path(goal), params: {
          goal_completion: {
            date: Date.current,
            actual_minutes: 60
          }
        }

        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "PATCH /goals/:goal_id/goal_completions/:id" do
    let!(:completion) do
      goal.goal_completions.create!(
        date: Date.current - 1.day,
        actual_minutes: 30
      )
    end

    context "when logged in" do
      before { login_as(user) }

      context "with valid parameters" do
        it "updates the completion record" do
          patch goal_goal_completion_path(goal, completion), params: {
            goal_completion: {
              actual_minutes: 90
            }
          }

          completion.reload
          expect(completion.actual_minutes).to eq(90)
        end

        it "recalculates achievement status after update" do
          # Completion started with 30 minutes (< 60 target, so not achieved)
          expect(completion.achieved).to eq(false)

          # Update to 70 minutes (> 60 target, should now be achieved)
          patch goal_goal_completion_path(goal, completion), params: {
            goal_completion: {
              actual_minutes: 70
            }
          }

          completion.reload
          expect(completion.achieved).to eq(true)
        end

        it "redirects to goal page with success message" do
          patch goal_goal_completion_path(goal, completion), params: {
            goal_completion: {
              actual_minutes: 80
            }
          }

          expect(response).to redirect_to(goal_path(goal))
          follow_redirect!
          expect(response.body).to include('Goal completion updated')
        end
      end

      context "with invalid parameters" do
        it "does not update with invalid actual minutes" do
          original_minutes = completion.actual_minutes

          patch goal_goal_completion_path(goal, completion), params: {
            goal_completion: {
              actual_minutes: -20
            }
          }

          completion.reload
          expect(completion.actual_minutes).to eq(original_minutes)

          expect(response).to redirect_to(goal_path(goal))
          follow_redirect!
          expect(response.body).to include('Unable to update completion')
        end
      end

      context "authorization" do
        let!(:other_completion) do
          other_goal.goal_completions.create!(
            date: Date.current,
            actual_minutes: 50
          )
        end

        it "prevents updating completions for other users' goals" do
          original_minutes = other_completion.actual_minutes

          # Logged in as user, trying to update other_completion which belongs to other_user's goal
          patch goal_goal_completion_path(other_goal, other_completion), params: {
            goal_completion: {
              actual_minutes: 100
            }
          }

          other_completion.reload
          expect(other_completion.actual_minutes).to eq(original_minutes)

          expect(response).to redirect_to(goals_path)
          follow_redirect!
          expect(response.body).to include('Goal not found or access denied')
        end
      end
    end

    context "when not logged in" do
      it "redirects to login page" do
        patch goal_goal_completion_path(goal, completion), params: {
          goal_completion: {
            actual_minutes: 80
          }
        }

        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end