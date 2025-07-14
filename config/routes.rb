Rails.application.routes.draw do
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  
  # Sidekiq Web UI with authentication
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq', constraints: AdminConstraint.new
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Authentication routes
  get '/login', to: 'sessions#new', as: 'login'
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy', as: 'logout'
  
  # Admin namespace
  namespace :admin do
    get '/', to: 'dashboard#index', as: 'dashboard'
    get '/embedding', to: 'dashboard#embedding', as: 'embedding_dashboard'
    
    # Future admin features
    resources :users, only: [:index, :show, :edit, :update]
  end

  # Defines the root path route ("/")
  root "home#index"
end