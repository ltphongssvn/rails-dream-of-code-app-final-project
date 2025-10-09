Rails.application.routes.draw do
  # Root path - landing page that's accessible to everyone
  # Logged-in users will be automatically redirected to their time entries
  root "home#index"

  # Authentication - using singular resource for session
  resource :session, only: [:new, :create, :destroy]
  resources :passwords, only: [:new, :create, :edit, :update]

  # Main application resources
  resources :time_entries
  resources :categories do
    member do
      get :subcategories
    end
  end

  resources :goals do
    resources :goal_completions, only: [:create, :update]
  end

  # Dashboard
  get 'dashboard', to: 'dashboard#show'

  # Reports
  namespace :reports do
    get 'daily', to: 'daily#daily'
    get 'weekly', to: 'weekly#show'
    get 'monthly', to: 'monthly#show'
    get 'category_breakdown', to: 'categories#index'
  end

  # User registration if needed
  resources :registrations, only: [:new, :create]
end

