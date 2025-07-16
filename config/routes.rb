Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Authentication routes
  get '/login', to: 'sessions#new'
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'

  # Admin routes
  namespace :admin do
    get '/dashboard', to: 'dashboard#index'
    get '/dashboard/embedding', to: 'dashboard#embedding'
  end

  # API routes
  namespace :api do
    # Search endpoints
    post 'search', to: 'search#create'
    post 'search/vector', to: 'search#vector_search'
    post 'search/hybrid', to: 'search#hybrid_search'
    post 'search/rag', to: 'search#rag'
    post 'search/ab_test', to: 'search#ab_test'
    
    # Stats and health
    get 'search/stats', to: 'search#stats'
    get 'health', to: 'search#health'
    
    # Chat API endpoints
    resources :conversations, only: [:show, :create, :destroy] do
      resources :messages, only: [:index, :create]
      member do
        post :extend_session
        get :status
      end
    end
    
    # Legacy support
    resources :search, only: [:index, :create]
  end

  # Chat UI routes
  resources :conversations, only: [:show, :create, :destroy], path: 'chat' do
    resources :messages, only: [:create]
    member do
      post :extend_session
    end
  end

  # Regulation imports
  resources :regulation_imports, only: [:index, :show]

  # Root route
  root 'home#index'
end