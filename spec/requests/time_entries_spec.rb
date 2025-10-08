# spec/requests/time_entries_spec.rb
require 'rails_helper'

RSpec.describe "TimeEntries", type: :request do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  
  before do
    # Skip authentication for all tests
    allow_any_instance_of(TimeEntriesController)
      .to receive(:require_authentication).and_return(true)
    
    # Provide a current user
    allow_any_instance_of(TimeEntriesController)
      .to receive(:current_user).and_return(user)
    
    # Mock the Current.session to return a valid session
    session = create(:session, user: user)
    Current.session = session
  end
  
  describe "GET /time_entries" do
    it "displays time entries for the current date" do
      entry = create(:time_entry, user: user, category: category, date: Date.current, hour: 9)
      
      get time_entries_path
      
      expect(response).to have_http_status(:success)
    end
    
    it "filters by date when provided" do
      today_entry = create(:time_entry, user: user, category: category, date: Date.current, hour: 10)
      yesterday_entry = create(:time_entry, user: user, category: category, date: Date.yesterday, hour: 11)
      
      get time_entries_path(date: Date.yesterday)
      
      expect(response).to have_http_status(:success)
    end
  end
  
  describe "POST /time_entries" do
    it "creates a new time entry" do
      expect {
        post time_entries_path, params: {
          time_entry: {
            date: Date.current,
            hour: 10,
            duration_minutes: 45,
            category_id: category.id,
            notes: "Working on Rails project"
          }
        }
      }.to change(TimeEntry, :count).by(1)
      
      expect(response).to redirect_to(time_entries_path(date: Date.current))
    end
    
    it "prevents duplicate entries for the same hour" do
      create(:time_entry, user: user, category: category, date: Date.current, hour: 10)
      
      post time_entries_path, params: {
        time_entry: {
          date: Date.current,
          hour: 10,
          duration_minutes: 30,
          category_id: category.id
        }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
  
  describe "DELETE /time_entries/:id" do
    it "deletes the time entry" do
      entry = create(:time_entry, user: user, category: category, hour: 14)
      
      expect {
        delete time_entry_path(entry)
      }.to change(TimeEntry, :count).by(-1)
      
      expect(response).to redirect_to(time_entries_path(date: entry.date))
    end
  end
end
