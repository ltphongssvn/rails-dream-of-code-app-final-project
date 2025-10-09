require 'rails_helper'

RSpec.describe "Dashboards", type: :request do
  let!(:user) { create(:user) }
  
  def login_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: 'SecurePassword123!'
    }
  end

  describe "GET /show" do
    context "when logged in" do
      before { login_as(user) }
      
      it "returns http success" do
        get "/dashboard"
        expect(response).to have_http_status(:success)
      end
    end
  end
end
