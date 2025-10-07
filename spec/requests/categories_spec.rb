# spec/requests/categories_spec.rb
require 'rails_helper'

RSpec.describe "Categories", type: :request do
  let!(:user) { create(:user) }
  let!(:other_user) { create(:user) }
  
  # Helper method to log in a user
  def login_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: 'SecurePassword123!'
    }
  end

  describe "GET /categories" do
    context "when not logged in" do
      it "redirects to login page" do
        get categories_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when logged in" do
      before { login_as(user) }

      it "displays the user's categories" do
        category1 = create(:category, user: user, name: "Work")
        category2 = create(:category, user: user, name: "Personal")
        
        get categories_path
        expect(response).to have_http_status(200)
        expect(response.body).to include("Work")
        expect(response.body).to include("Personal")
      end

      it "does not display other users' categories" do
        user_category = create(:category, user: user, name: "My Category")
        other_category = create(:category, user: other_user, name: "Other Category")
        
        get categories_path
        expect(response.body).to include("My Category")
        expect(response.body).not_to include("Other Category")
      end

      it "displays categories in hierarchical structure" do
        parent = create(:category, user: user, name: "Learning")
        child = create(:category, user: user, name: "Rails", parent_category: parent)
        
        get categories_path
        expect(response).to have_http_status(200)
        # Both parent and child should be visible
        expect(response.body).to include("Learning")
        expect(response.body).to include("Rails")
      end
    end
  end

  describe "GET /categories/:id" do
    context "when logged in" do
      before { login_as(user) }

      it "shows the category details" do
        category = create(:category, user: user, name: "Exercise")
        
        get category_path(category)
        expect(response).to have_http_status(200)
        expect(response.body).to include("Exercise")
      end

      it "prevents viewing other users' categories" do
        other_category = create(:category, user: other_user)
        
        get category_path(other_category)
        expect(response).to redirect_to(categories_path)
        follow_redirect!
        expect(response.body).to include("Category not found")
      end

      it "displays subcategories" do
        parent = create(:category, user: user, name: "Work")
        child1 = create(:category, user: user, name: "Meetings", parent_category: parent)
        child2 = create(:category, user: user, name: "Coding", parent_category: parent)
        
        get category_path(parent)
        expect(response).to have_http_status(200)
        expect(response.body).to include("Meetings")
        expect(response.body).to include("Coding")
      end
    end
  end

  describe "GET /categories/new" do
    context "when not logged in" do
      it "redirects to login page" do
        get new_category_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when logged in" do
      before { login_as(user) }

      it "displays the new category form" do
        get new_category_path
        expect(response).to have_http_status(200)
        expect(response.body).to include("name")
        expect(response.body).to include("color")
      end
    end
  end

  describe "POST /categories" do
    context "when logged in" do
      before { login_as(user) }

      it "creates a new category with valid parameters" do
        expect {
          post categories_path, params: {
            category: {
              name: "Reading",
              color: "#00FF00"
            }
          }
        }.to change(user.categories, :count).by(1)
        
        expect(response).to redirect_to(categories_path)
        follow_redirect!
        expect(response.body).to include("Category was successfully created")
      end

      it "creates a subcategory with parent_category_id" do
        parent = create(:category, user: user, name: "Learning")
        
        post categories_path, params: {
          category: {
            name: "Ruby",
            color: "#FF0000",
            parent_category_id: parent.id
          }
        }
        
        new_category = Category.last
        expect(new_category.parent_category).to eq(parent)
        expect(new_category.name).to eq("Ruby")
      end

      it "does not create category with invalid parameters" do
        expect {
          post categories_path, params: {
            category: {
              name: "",  # Name is required
              color: "#00FF00"
            }
          }
        }.not_to change(Category, :count)
        
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "assigns a default color if none provided" do
        post categories_path, params: {
          category: {
            name: "No Color Category"
          }
        }
        
        new_category = Category.last
        expect(new_category.color).to match(/\A#[0-9A-Fa-f]{6}\z/)
      end
    end
  end

  describe "GET /categories/:id/edit" do
    context "when logged in" do
      before { login_as(user) }

      it "displays the edit form for user's category" do
        category = create(:category, user: user, name: "Study")
        
        get edit_category_path(category)
        expect(response).to have_http_status(200)
        expect(response.body).to include("Study")
      end

      it "prevents editing other users' categories" do
        other_category = create(:category, user: other_user)
        
        get edit_category_path(other_category)
        expect(response).to redirect_to(categories_path)
        follow_redirect!
        expect(response.body).to include("Category not found")
      end
    end
  end

  describe "PATCH /categories/:id" do
    context "when logged in" do
      before { login_as(user) }

      it "updates the category with valid parameters" do
        category = create(:category, user: user, name: "Old Name")
        
        patch category_path(category), params: {
          category: {
            name: "New Name",
            color: "#AABBCC"
          }
        }
        
        category.reload
        expect(category.name).to eq("New Name")
        expect(category.color).to eq("#AABBCC")
        expect(response).to redirect_to(categories_path)
      end

      it "does not update with invalid parameters" do
        category = create(:category, user: user, name: "Valid Name")
        
        patch category_path(category), params: {
          category: {
            name: ""  # Invalid - name is required
          }
        }
        
        category.reload
        expect(category.name).to eq("Valid Name")  # Should not change
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "prevents updating other users' categories" do
        other_category = create(:category, user: other_user, name: "Other")
        
        patch category_path(other_category), params: {
          category: { name: "Hacked" }
        }
        
        other_category.reload
        expect(other_category.name).to eq("Other")  # Should not change
        expect(response).to redirect_to(categories_path)
      end
    end
  end

  describe "DELETE /categories/:id" do
    context "when logged in" do
      before { login_as(user) }

      it "deletes a category without time entries" do
        category = create(:category, user: user)
        
        expect {
          delete category_path(category)
        }.to change(user.categories, :count).by(-1)
        
        expect(response).to redirect_to(categories_path)
        follow_redirect!
        expect(response.body).to include("successfully deleted")
      end

      it "prevents deleting a category with time entries" do
        category = create(:category, user: user)
        create(:time_entry, user: user, category: category)
        
        expect {
          delete category_path(category)
        }.not_to change(Category, :count)
        
        expect(response).to redirect_to(categories_path)
        follow_redirect!
        expect(response.body).to include("Cannot delete category that has time entries")
      end

      it "prevents deleting other users' categories" do
        other_category = create(:category, user: other_user)
        
        expect {
          delete category_path(other_category)
        }.not_to change(Category, :count)
        
        expect(response).to redirect_to(categories_path)
      end
    end
  end

  describe "GET /categories/:id/subcategories" do
    context "when logged in" do
      before { login_as(user) }

      it "returns subcategories as JSON" do
        parent = create(:category, user: user, name: "Work")
        child1 = create(:category, user: user, name: "Admin", parent_category: parent, color: "#111111")
        child2 = create(:category, user: user, name: "Development", parent_category: parent, color: "#222222")
        
        get subcategories_category_path(parent)
        expect(response).to have_http_status(200)
        expect(response.content_type).to include("application/json")
        
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(2)
        expect(json_response.first["name"]).to eq("Admin")
        expect(json_response.first["color"]).to eq("#111111")
      end

      it "returns empty array for category without subcategories" do
        category = create(:category, user: user)
        
        get subcategories_category_path(category)
        expect(response).to have_http_status(200)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to eq([])
      end
    end
  end
end
