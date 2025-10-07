# app/controllers/home_controller.rb
class HomeController < ApplicationController
  # Allow anyone to view the home page without logging in
  allow_unauthenticated_access

  def index
    # Render the home page for everyone
    # The view will handle displaying appropriate content based on authentication status
    # This avoids double redirects and allows flash messages to display properly
  end
end
