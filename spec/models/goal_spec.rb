# spec/models/goal_spec.rb
require 'rails_helper'

RSpec.describe Goal, type: :model do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let(:valid_attributes) do
    {
      user: user,
      category: category,
      goal_type: 'daily',
      target_minutes: 60,
      days_of_week: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
    }
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:category).optional }
    it { should have_many(:goal_completions).dependent(:destroy) }
  end
  
  describe 'validations' do
    it 'is valid with valid attributes' do
      goal = Goal.new(valid_attributes)
      expect(goal).to be_valid
    end
    
    it 'requires a user' do
      goal = Goal.new(valid_attributes.except(:user))
      expect(goal).not_to be_valid
      expect(goal.errors[:user]).to include("must exist")
    end
    
    it 'allows goals without categories' do
      goal = Goal.new(valid_attributes.merge(category: nil))
      expect(goal).to be_valid
    end
    
    it 'requires a goal_type' do
      goal = Goal.new(valid_attributes.merge(goal_type: nil))
      expect(goal).not_to be_valid
      expect(goal.errors[:goal_type]).to include("can't be blank")
    end
    
    it 'validates goal_type is within allowed values' do
      goal = Goal.new(valid_attributes.merge(goal_type: 'invalid_type'))
      expect(goal).not_to be_valid
      # The database constraint will catch this
    end
    
    it 'requires target_minutes' do
      goal = Goal.new(valid_attributes.merge(target_minutes: nil))
      expect(goal).not_to be_valid
      expect(goal.errors[:target_minutes]).to include("can't be blank")
    end
    
    it 'validates target_minutes is positive' do
      goal = Goal.new(valid_attributes.merge(target_minutes: 0))
      expect(goal).not_to be_valid
      expect(goal.errors[:target_minutes]).to include("must be greater than 0")
    end
    
    it 'validates target_minutes is reasonable' do
      goal = Goal.new(valid_attributes.merge(target_minutes: 1441))
      expect(goal).not_to be_valid
      expect(goal.errors[:target_minutes]).to include("must be less than or equal to 1440")
    end
    
    describe 'hour validation for specific_hour goals' do
      it 'requires hour for specific_hour goal type' do
        goal = Goal.new(valid_attributes.merge(goal_type: 'specific_hour', hour: nil))
        expect(goal).not_to be_valid
        expect(goal.errors[:hour]).to include("is required for specific hour goals")
      end
      
      it 'validates hour is between 0 and 23' do
        goal = Goal.new(valid_attributes.merge(goal_type: 'specific_hour', hour: 24))
        expect(goal).not_to be_valid
        expect(goal.errors[:hour]).to include("must be between 0 and 23")
      end
      
      it 'does not allow hour for non-specific_hour goals' do
        goal = Goal.new(valid_attributes.merge(goal_type: 'daily', hour: 9))
        expect(goal).not_to be_valid
        expect(goal.errors[:hour]).to include("should not be set for daily or weekly goals")
      end
    end
  end
  
  describe 'scopes' do
    before do
      @active_goal = create(:goal, user: user, active: true)
      @inactive_goal = create(:goal, user: user, active: false)
      @daily_goal = create(:goal, user: user, goal_type: 'daily')
      @weekly_goal = create(:goal, user: user, goal_type: 'weekly')
      @morning_goal = create(:goal, user: user, goal_type: 'specific_hour', hour: 9)
    end
    
    it 'returns only active goals with .active scope' do
      active = Goal.active
      expect(active).to include(@active_goal)
      expect(active).not_to include(@inactive_goal)
    end
    
    it 'filters by goal type' do
      daily = Goal.by_type('daily')
      expect(daily).to include(@daily_goal)
      expect(daily).not_to include(@weekly_goal)
    end
    
    it 'returns goals for specific day of week' do
      monday_goal = create(:goal, user: user, days_array: ['Monday'])
      tuesday_goal = create(:goal, user: user, days_array: ['Tuesday'])
      
      monday_goals = Goal.for_day_of_week('Monday')
      expect(monday_goals).to include(monday_goal)
      expect(monday_goals).not_to include(tuesday_goal)
    end
  end
  
  describe 'instance methods' do
    describe '#applies_on_date?' do
      let(:goal) { create(:goal, user: user, days_array: ['Monday', 'Wednesday', 'Friday']) }
      
      it 'returns true for applicable days' do
        monday = Date.parse('2025-10-06') # A Monday
        expect(goal.applies_on_date?(monday)).to be true
      end
      
      it 'returns false for non-applicable days' do
        tuesday = Date.parse('2025-10-07') # A Tuesday
        expect(goal.applies_on_date?(tuesday)).to be false
      end
    end
    
    describe '#completion_for_date' do
      let(:goal) { create(:goal, user: user) }
      let(:date) { Date.today }
      
      it 'returns the completion record for a specific date' do
        completion = create(:goal_completion, goal: goal, date: date, achieved: true)
        expect(goal.completion_for_date(date)).to eq(completion)
      end
      
      it 'returns nil if no completion exists' do
        expect(goal.completion_for_date(date)).to be_nil
      end
    end
    
    describe '#achieved_on_date?' do
      let(:goal) { create(:goal, user: user) }
      let(:date) { Date.today }
      
      it 'returns true if goal was achieved' do
        create(:goal_completion, goal: goal, date: date, achieved: true)
        expect(goal.achieved_on_date?(date)).to be true
      end
      
      it 'returns false if goal was not achieved' do
        create(:goal_completion, goal: goal, date: date, achieved: false)
        expect(goal.achieved_on_date?(date)).to be false
      end
      
      it 'returns false if no completion exists' do
        expect(goal.achieved_on_date?(date)).to be false
      end
    end
    
    describe '#completion_rate' do
      let(:goal) { create(:goal, user: user) }
      
      it 'calculates percentage of successful completions' do
        create(:goal_completion, goal: goal, date: Date.today, achieved: true)
        create(:goal_completion, goal: goal, date: Date.today - 1, achieved: true)
        create(:goal_completion, goal: goal, date: Date.today - 2, achieved: false)
        create(:goal_completion, goal: goal, date: Date.today - 3, achieved: false)
        
        expect(goal.completion_rate).to eq(50.0)
      end
      
      it 'returns 0 if no completions exist' do
        expect(goal.completion_rate).to eq(0)
      end
      
      it 'returns 100 if all completions are successful' do
        create(:goal_completion, goal: goal, date: Date.today, achieved: true)
        create(:goal_completion, goal: goal, date: Date.today - 1, achieved: true)
        
        expect(goal.completion_rate).to eq(100.0)
      end
    end
    
    describe '#current_streak' do
      let(:goal) { create(:goal, user: user, created_at: 1.week.ago) }
      
      it 'calculates consecutive days of achievement' do
        create(:goal_completion, goal: goal, date: Date.today, achieved: true)
        create(:goal_completion, goal: goal, date: Date.today - 1, achieved: true)
        create(:goal_completion, goal: goal, date: Date.today - 2, achieved: true)
        create(:goal_completion, goal: goal, date: Date.today - 3, achieved: false)
        
        expect(goal.current_streak).to eq(2)
      end
      
      it 'returns 0 if latest completion was not achieved' do
        create(:goal_completion, goal: goal, date: Date.today, achieved: false)
        create(:goal_completion, goal: goal, date: Date.today - 1, achieved: true)
        
        expect(goal.current_streak).to eq(0)
      end
      
      it 'handles gaps in completion records' do
        create(:goal_completion, goal: goal, date: Date.today, achieved: true)
        create(:goal_completion, goal: goal, date: Date.today - 2, achieved: true)
        
        expect(goal.current_streak).to eq(1)
      end
    end
    
    describe '#check_and_record_completion' do
      let(:goal) { create(:goal, user: user, category: category, target_minutes: 60) }
      let(:date) { Date.today }
      
      it 'creates completion record as achieved if target met' do
        create(:time_entry, user: user, category: category, date: date, duration_minutes: 60)
        
        completion = goal.check_and_record_completion(date)
        expect(completion.achieved).to be true
        expect(completion.actual_minutes).to eq(60)
      end
      
      it 'creates completion record as not achieved if target not met' do
        create(:time_entry, user: user, category: category, date: date, duration_minutes: 30)
        
        completion = goal.check_and_record_completion(date)
        expect(completion.achieved).to be false
        expect(completion.actual_minutes).to eq(30)
      end
      
      it 'updates existing completion record' do
        existing = create(:goal_completion, goal: goal, date: date, achieved: false, actual_minutes: 30)
        create(:time_entry, user: user, category: category, date: date, duration_minutes: 60)
        
        completion = goal.check_and_record_completion(date)
        expect(completion.id).to eq(existing.id)
        expect(completion.achieved).to be true
        expect(completion.actual_minutes).to eq(60)
      end
    end
  end
  
  describe 'weekly goals' do
    let(:weekly_goal) { create(:goal, user: user, goal_type: 'weekly', target_minutes: 300) }
    
    it 'calculates weekly progress correctly' do
      monday = 1.week.ago.beginning_of_week
      create(:time_entry, user: user, category: category, date: monday, hour: 9, duration_minutes: 60)
      create(:time_entry, user: user, category: category, date: monday + 1, hour: 10, duration_minutes: 50)
      create(:time_entry, user: user, category: category, date: monday + 2, hour: 11, duration_minutes: 40)
      
      weekly_goal.category = category
      expect(weekly_goal.weekly_progress(monday)).to eq(150)
    end
  end
end