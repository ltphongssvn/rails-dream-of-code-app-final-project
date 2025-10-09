# spec/models/goal_completion_spec.rb
require 'rails_helper'

RSpec.describe GoalCompletion, type: :model do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let(:goal) { create(:goal, user: user, category: category, target_minutes: 60, created_at: 1.week.ago) }

  describe 'associations' do
    it { should belong_to(:goal) }
    it { should have_one(:user).through(:goal) }
    it { should have_one(:category).through(:goal) }
  end

  describe 'validations' do
    subject { create(:goal_completion, goal: goal) }

    it { should validate_presence_of(:goal) }
    it { should validate_presence_of(:date) }

    it 'validates actual_minutes is non-negative' do
      completion = build(:goal_completion, goal: goal, actual_minutes: -1)
      expect(completion).not_to be_valid
      expect(completion.errors[:actual_minutes]).to include('must be greater than or equal to 0')
    end

    it 'validates actual_minutes is less than a day' do
      completion = build(:goal_completion, goal: goal, actual_minutes: 1441)
      expect(completion).not_to be_valid
      expect(completion.errors[:actual_minutes]).to include('must be less than or equal to 1440')
    end

    it 'allows nil actual_minutes' do
      completion = build(:goal_completion, goal: goal, actual_minutes: nil)
      expect(completion).to be_valid
    end

    it 'prevents duplicate completions for same goal and date' do
      create(:goal_completion, goal: goal, date: Date.today)
      duplicate = build(:goal_completion, goal: goal, date: Date.today)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:goal_id]).to include('already has a completion record for this date')
    end

    it 'allows same date for different goals' do
      other_goal = create(:goal, user: user)
      create(:goal_completion, goal: goal, date: Date.today)
      other_completion = build(:goal_completion, goal: other_goal, date: Date.today)
      expect(other_completion).to be_valid
    end
  end

  describe 'scopes' do
    let!(:achieved_completion) { create(:goal_completion, goal: goal, achieved: true, date: Date.today) }
    let!(:missed_completion) { create(:goal_completion, goal: goal, achieved: false, actual_minutes: 30, date: Date.today - 1) }
    let!(:pending_completion) { create(:goal_completion, goal: goal, achieved: false, date: Date.today - 2) }

    it 'returns achieved completions with .achieved scope' do
      expect(GoalCompletion.achieved).to include(achieved_completion)
      expect(GoalCompletion.achieved).not_to include(missed_completion, pending_completion)
    end

    it 'returns missed completions with .missed scope' do
      expect(GoalCompletion.missed).to include(missed_completion)
      expect(GoalCompletion.missed).not_to include(achieved_completion, pending_completion)
    end

    it 'returns pending completions with .where(achieved: false, actual_minutes: 0) scope' do
      expect(GoalCompletion.where(achieved: false, actual_minutes: 0)).to include(pending_completion)
      expect(GoalCompletion.where(achieved: false, actual_minutes: 0)).not_to include(achieved_completion, missed_completion)
    end

    it 'filters by date with .for_date scope' do
      today_completions = GoalCompletion.for_date(Date.today)
      expect(today_completions).to include(achieved_completion)
      expect(today_completions).not_to include(missed_completion, pending_completion)
    end

    it 'orders by date descending with .recent scope' do
      completions = GoalCompletion.recent
      expect(completions.first).to eq(achieved_completion)
      expect(completions.last).to eq(pending_completion)
    end

    it 'filters by date range' do
      range_completions = GoalCompletion.date_range(Date.today - 1, Date.today)
      expect(range_completions).to include(achieved_completion, missed_completion)
      expect(range_completions).not_to include(pending_completion)
    end
  end

  describe 'callbacks' do
    it 'sets achievement status when actual_minutes changes' do
      completion = create(:goal_completion, goal: goal, actual_minutes: 0, achieved: false)
      expect(completion.achieved).to be false

      completion.update(actual_minutes: 70)
      expect(completion.achieved).to be true

      completion.update(actual_minutes: 30)
      expect(completion.achieved).to be false
    end
  end

  describe '#calculate_achievement' do
    it 'returns true when actual minutes meet target' do
      completion = build(:goal_completion, goal: goal, actual_minutes: 60)
      expect(completion.calculate_achievement).to be true
    end

    it 'returns true when actual minutes exceed target' do
      completion = build(:goal_completion, goal: goal, actual_minutes: 75)
      expect(completion.calculate_achievement).to be true
    end

    it 'returns false when actual minutes are below target' do
      completion = build(:goal_completion, goal: goal, actual_minutes: 45)
      expect(completion.calculate_achievement).to be false
    end

    it 'returns nil when actual_minutes is nil' do
      completion = build(:goal_completion, goal: goal, actual_minutes: nil)
      expect(completion.calculate_achievement).to be_nil
    end
  end

  describe '#completion_percentage' do
    it 'calculates correct percentage' do
      completion = build(:goal_completion, goal: goal, actual_minutes: 45)
      expect(completion.completion_percentage).to eq(75.0)
    end

    it 'caps at 100% when exceeding target' do
      completion = build(:goal_completion, goal: goal, actual_minutes: 90)
      expect(completion.completion_percentage).to eq(100.0)
    end

    it 'returns 0 when actual_minutes is nil' do
      completion = build(:goal_completion, goal: goal, actual_minutes: nil)
      expect(completion.completion_percentage).to eq(0)
    end

    it 'returns 0 when actual_minutes is 0' do
      completion = build(:goal_completion, goal: goal, actual_minutes: 0)
      expect(completion.completion_percentage).to eq(0)
    end
  end

  describe '#part_of_streak?' do
    context 'when completion is achieved' do
      let(:completion) { create(:goal_completion, goal: goal, date: Date.today, achieved: true) }

      it 'returns true when previous applicable day was also achieved' do
        # Create an achievement for the previous weekday
        previous_date = Date.today - 1
        previous_date -= 1 while !goal.applies_to_date?(previous_date)
        create(:goal_completion, goal: goal, date: previous_date, achieved: true)

        expect(completion.part_of_streak?).to be true
      end

      it 'returns false when previous applicable day was not achieved' do
        previous_date = Date.today - 1
        previous_date -= 1 while !goal.applies_to_date?(previous_date)
        create(:goal_completion, goal: goal, date: previous_date, achieved: false)

        expect(completion.part_of_streak?).to be false
      end

      it 'returns true when it is the first completion' do
        fresh_goal = create(:goal, user: user, category: category, target_minutes: 60)
        first_completion = create(:goal_completion, goal: fresh_goal, date: Date.today, achieved: true)
        expect(first_completion.part_of_streak?).to be true
      end
    end

    context 'when completion is not achieved' do
      let(:completion) { create(:goal_completion, goal: goal, date: Date.today, achieved: false) }

      it 'returns false' do
        expect(completion.part_of_streak?).to be false
      end
    end
  end

  describe '#streak_length' do
    it 'calculates streak length correctly for single achievement' do
      completion = create(:goal_completion, goal: goal, date: Date.today, achieved: true)
      expect(completion.streak_length).to eq(1)
    end

    it 'calculates streak length for multiple consecutive achievements' do
      # Create achievements for today and previous applicable days
      dates = []
      current_date = Date.today
      3.times do
        if goal.applies_to_date?(current_date)
          dates << current_date
          create(:goal_completion, goal: goal, date: current_date, achieved: true)
        end
        current_date -= 1
        # Skip non-applicable days
        current_date -= 1 while current_date >= goal.created_at.to_date && !goal.applies_to_date?(current_date)
      end

      completion = GoalCompletion.find_by(date: Date.today)
      expect(completion.streak_length).to be >= 1
    end

    it 'returns 0 for non-achieved completion' do
      completion = create(:goal_completion, goal: goal, date: Date.today, achieved: false)
      expect(completion.streak_length).to eq(0)
    end
  end

  describe '#status' do
    it 'returns pending when achieved is nil' do
      completion = build(:goal_completion, achieved: false)
      expect(completion.status).to eq('pending')
    end

    it 'returns achieved when achieved is true' do
      completion = build(:goal_completion, achieved: true)
      expect(completion.status).to eq('achieved')
    end

    it 'returns missed when achieved is false' do
      completion = build(:goal_completion, achieved: false, actual_minutes: 30)
      expect(completion.status).to eq('missed')
    end
  end

  describe '#summary' do
    it 'provides summary for achieved completion' do
      completion = create(:goal_completion, goal: goal, actual_minutes: 75, achieved: true)
      expect(completion.summary).to eq("Achieved: 75/60 minutes (100.0%)")
    end

    it 'provides summary for missed completion' do
      completion = create(:goal_completion, goal: goal, actual_minutes: 30, achieved: false)
      expect(completion.summary).to eq("Missed: 30/60 minutes (50.0%)")
    end

    it 'provides summary for pending completion' do
      completion = create(:goal_completion, goal: goal, achieved: false)
      expect(completion.summary).to include("Goal pending")
    end

    it 'handles nil actual_minutes in missed summary' do
      completion = create(:goal_completion, goal: goal, actual_minutes: 0, achieved: false)
      expect(completion.summary).to eq("Goal pending: 60 minutes target")
    end
  end
end