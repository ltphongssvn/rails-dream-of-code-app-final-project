   # spec/models/time_entry_spec.rb
   require 'rails_helper'

   RSpec.describe TimeEntry, type: :model do
     # Create test data
     let(:user) {
       User.create!(
         email_address: 'test@example.com',
         password: 'password123',
         first_name: 'Test',
         last_name: 'User',
         time_zone: 'Pacific Time (US & Canada)'
       )
     }

     let(:category) {
       Category.create!(
         user: user,
         name: 'Work',
         color: '#0000FF'
       )
     }

     let(:valid_attributes) {
       {
         user: user,
         category: category,
         date: Date.current,
         hour: 9,
         duration_minutes: 45,
         notes: 'Worked on project documentation'
       }
     }

     describe 'associations' do
       it { should belong_to(:user) }
       it { should belong_to(:category) }
     end

     describe 'validations' do
       it 'is valid with valid attributes' do
         entry = TimeEntry.new(valid_attributes)
         expect(entry).to be_valid
       end

       it 'requires a user' do
         entry = TimeEntry.new(valid_attributes.except(:user))
         expect(entry).not_to be_valid
         expect(entry.errors[:user]).to include('must exist')
       end

       it 'requires a category' do
         entry = TimeEntry.new(valid_attributes.except(:category))
         expect(entry).not_to be_valid
         expect(entry.errors[:category]).to include('must exist')
       end

       it 'requires a date' do
         entry = TimeEntry.new(valid_attributes.except(:date))
         expect(entry).not_to be_valid
         expect(entry.errors[:date]).to include("can't be blank")
       end

       it 'requires an hour' do
         entry = TimeEntry.new(valid_attributes.except(:hour))
         expect(entry).not_to be_valid
         expect(entry.errors[:hour]).to include("can't be blank")
       end

       it 'requires duration_minutes' do
         entry = TimeEntry.new(valid_attributes.merge(duration_minutes: nil))
         expect(entry).not_to be_valid
         expect(entry.errors[:duration_minutes]).to include("can't be blank")
       end

       it 'validates duration is between 1 and 60' do
         # Test upper bound
         entry = TimeEntry.new(valid_attributes.merge(duration_minutes: 61))
         expect(entry).not_to be_valid
         expect(entry.errors[:duration_minutes]).to include('must be between 1 and 60 minutes')

         # Test lower bound
         entry = TimeEntry.new(valid_attributes.merge(duration_minutes: 0))
         expect(entry).not_to be_valid
         expect(entry.errors[:duration_minutes]).to include('must be between 1 and 60 minutes')
       end

       it 'validates hour is between 0 and 23' do
         # Test upper bound
         entry = TimeEntry.new(valid_attributes.merge(hour: 24))
         expect(entry).not_to be_valid
         expect(entry.errors[:hour]).to include('must be between 0 (midnight) and 23 (11 PM)')

         # Test lower bound
         entry = TimeEntry.new(valid_attributes.merge(hour: -1))
         expect(entry).not_to be_valid
         expect(entry.errors[:hour]).to include('must be between 0 (midnight) and 23 (11 PM)')
       end

       it 'prevents duplicate entries for same user, date, and hour' do
         TimeEntry.create!(valid_attributes)
         duplicate = TimeEntry.new(valid_attributes)
         expect(duplicate).not_to be_valid
         expect(duplicate.errors[:hour]).to include('already has an entry for this time slot')
       end

       it 'prevents entries for future dates' do
         future_entry = TimeEntry.new(valid_attributes.merge(date: Date.tomorrow))
         expect(future_entry).not_to be_valid
         expect(future_entry.errors[:date]).to include("can't be in the future")
       end
     end

     describe 'scopes' do
       before do
         @today_entry = TimeEntry.create!(valid_attributes)
         @yesterday_entry = TimeEntry.create!(
           valid_attributes.merge(date: Date.yesterday, hour: 10)
         )
       end

       it 'filters by date with for_date scope' do
         entries = TimeEntry.for_date(Date.current)
         expect(entries).to include(@today_entry)
         expect(entries).not_to include(@yesterday_entry)
       end

       it 'filters by date range' do
         entries = TimeEntry.date_range(Date.yesterday, Date.current)
         expect(entries).to include(@today_entry, @yesterday_entry)
       end
     end

     describe 'instance methods' do
       let(:entry) { TimeEntry.new(valid_attributes) }

       it 'formats hour with display_hour' do
         expect(entry.display_hour).to eq('9:00 AM')

         afternoon = TimeEntry.new(valid_attributes.merge(hour: 14))
         expect(afternoon.display_hour).to eq('2:00 PM')
       end

       it 'detects overlaps with overlaps_with?' do
         existing = TimeEntry.create!(valid_attributes)
         overlapping = TimeEntry.new(valid_attributes)

         expect(overlapping.overlaps_with?(existing)).to be true

         different_hour = TimeEntry.new(valid_attributes.merge(hour: 10))
         expect(different_hour.overlaps_with?(existing)).to be false
       end
     end
   end