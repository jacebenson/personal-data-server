Rails.application.routes.draw do
  devise_for :users
  get "pages/home"

  # Category pages
  get "financial", to: "financial#index"
  get "personal", to: "personal#index"
  get "entertainment", to: "entertainment#index"
  get "shopping", to: "shopping#index"

  

  # Social Security management routes
  resources :social_security, only: [:index] do
    collection do
      post :upload_earnings
      get :view_earnings
      delete :clear_earnings
    end
  end

  # Communication management routes
  resources :communications, only: [:index, :show] do
    collection do
      post :upload_mbox
      post :upload_linkedin_messages
      get :view
      delete :clear
    end
  end

  # Calendar management routes
  resources :calendars do
    member do
      post :sync
    end
    
    collection do
      get :import
      post :upload_ics_file
      delete :clear_all
    end
  end
  
  # Event detail view
  get 'calendars/events/:id', to: 'calendars#show_event', as: 'calendar_event'

  # Personal data management routes
  resources :personal, only: [:index] do
    collection do
      get :upload
      post :upload_data
      get :view_data
      delete :clear_data
    end
  end

  # Financial data management routes
  resources :financial, only: [:index] do
    collection do
      get :bank_statements
      post :upload_bank_statements
      get :view_bank_statements
      get :fidelity_upload
      post :upload_fidelity_data
      get :principal_upload
      post :upload_principal_data
      get :view_investments
      get :manage_duplicates
      delete :remove_duplicates
      delete :clear_bank_statements
      delete :clear_investments
      post :add_balance_adjustment
    end
  end

  # Shopping/Amazon order management routes
  resources :shopping, only: [:index] do
    collection do
      get :upload
      get :upload_digital
      post :upload_orders
      post :upload_digital_orders
      get :view_orders
      delete :clear_orders
    end
  end

  # Contact management routes
  resources :contacts, only: [:index, :show, :edit, :update, :destroy] do
    collection do
      post :upload_vcard
      post :upload_linkedin_connections
      delete :clear
      get :duplicates
      post :merge
      get :auto_merge
      post :auto_merge
    end
  end

  # nullEDGE attendee tracking routes
  resources :null_edge, only: [:index] do
    collection do
      post :fetch_attendees
      get :view
      delete :clear
    end
  end

  # Health data routes
  resources :health, only: [ :index ] do
    collection do
      get :import
      post :process_import
    end
    
    member do
      get :allergies
      get :medications
      get :problems
      get :immunizations
      get :vital_signs
      get :encounters
      get :sleep_data
    end
  end

  # Entertainment content routes
  resources :entertainment, only: [:index]
  
  namespace :entertainment do
    # Netflix routes
    resources :netflix, only: [:index, :show] do
      collection do
        post :upload
        delete :destroy_all
      end
    end
    
    # YouTube routes  
    resources :youtube, only: [:index, :show] do
      collection do
        post :upload
        delete :destroy_all
      end
    end
    
    # Audible routes
    resources :audible, only: [:index, :show] do
      collection do
        post :upload
        delete :destroy_all
      end
    end
    
    # Audible Libraries routes
    resources :audible_libraries, only: [:index, :show] do
      collection do
        post :upload
        delete :destroy_all
      end
    end
    
    # Books (Goodreads) routes
    resources :books, only: [:index, :show] do
      collection do
        post :upload
        delete :destroy_all
      end
    end
    
    # Podcasts routes
    resources :podcasts, only: [:index] do
      collection do
        post :upload_opml
        post :add_feed
        post :sync_all
        delete :destroy_all
        get :all_episodes
      end
      
      member do
        post :sync
        patch :toggle
        delete :destroy
        get :episodes
      end
      
      # Podcast episode routes
      resources :episodes, only: [] do
        member do
          patch :toggle_listened
          get :show, action: :episode
        end
      end
    end
  end
  
  # Legacy route redirects to maintain existing URLs
  get 'entertainment/netflix', to: 'entertainment/netflix#index'
  get 'entertainment/view_netflix', to: 'entertainment/netflix#show'
  post 'entertainment/upload_netflix', to: 'entertainment/netflix#upload'
  delete 'entertainment/clear_netflix', to: 'entertainment/netflix#destroy_all'
  
  get 'entertainment/youtube', to: 'entertainment/youtube#index'
  get 'entertainment/view_youtube', to: 'entertainment/youtube#show'
  post 'entertainment/upload_youtube', to: 'entertainment/youtube#upload'
  delete 'entertainment/clear_youtube', to: 'entertainment/youtube#destroy_all'
  
  get 'entertainment/audible', to: 'entertainment/audible#index'
  get 'entertainment/view_audible', to: 'entertainment/audible#show'
  post 'entertainment/upload_audible', to: 'entertainment/audible#upload'
  delete 'entertainment/clear_audible', to: 'entertainment/audible#destroy_all'
  
  get 'entertainment/audible_library', to: 'entertainment/audible_libraries#index'
  get 'entertainment/view_audible_library', to: 'entertainment/audible_libraries#show'
  post 'entertainment/upload_audible_library', to: 'entertainment/audible_libraries#upload'
  delete 'entertainment/clear_audible_library', to: 'entertainment/audible_libraries#destroy_all'
  
  get 'entertainment/goodreads', to: 'entertainment/books#index'
  get 'entertainment/view_goodreads', to: 'entertainment/books#show'
  post 'entertainment/upload_goodreads', to: 'entertainment/books#upload'
  delete 'entertainment/clear_goodreads', to: 'entertainment/books#destroy_all'
  
  get 'entertainment/podcasts', to: 'entertainment/podcasts#index'
  post 'entertainment/upload_opml', to: 'entertainment/podcasts#upload_opml'
  post 'entertainment/add_podcast_feed', to: 'entertainment/podcasts#add_feed'
  delete 'entertainment/clear_podcast_feeds', to: 'entertainment/podcasts#destroy_all'
  get 'entertainment/all_episodes', to: 'entertainment/podcasts#all_episodes'
  
  # Individual podcast feed actions
  post 'entertainment/:id/sync_podcast_feed', to: 'entertainment/podcasts#sync'
  patch 'entertainment/:id/toggle_podcast_feed', to: 'entertainment/podcasts#toggle'
  delete 'entertainment/:id/delete_podcast_feed', to: 'entertainment/podcasts#destroy'
  
  # Podcast episodes
  get 'entertainment/podcast/:id', to: 'entertainment/podcasts#episodes', as: :podcast_episodes_entertainment_index
  get 'entertainment/podcast/:podcast_id/episode/:id', to: 'entertainment/podcasts#episode', as: :podcast_episode_entertainment_index
  patch 'entertainment/podcast/:podcast_id/episode/:id/toggle_listened', to: 'entertainment/podcasts#toggle_episode_listened', as: :toggle_episode_listened_entertainment_index
  
  # Podcast feed sync route (for syncing all)
  post 'entertainment/sync_all_podcast_feeds', to: 'entertainment/podcasts#sync_all'

  # API routes for AI model context providers
  namespace :api do
    namespace :v1 do
      # API Documentation endpoint (no auth required)
      get :docs, to: 'docs#index'
      
      # Overview endpoint - returns recent/active data from all categories
      get :overview, to: 'overview#index'
      
      # Health data API - single endpoint with search
      get :health, to: 'health#index'
      
      # Communications API - emails and linkedin with search
      get :communications, to: 'communications#index'
      
      # Transactions API - amazon orders and bank statements with search
      get :transactions, to: 'transactions#index'
      
      # MCP (Model Context Protocol) specific endpoints
      namespace :mcp do
        # Core Actions (Priority endpoints)
        post :search_all_data, to: 'search#search_all_data'
        post :find_person_contact, to: 'communications#find_person_contact'
        post :get_financial_summary, to: 'financial#get_financial_summary'
        post :find_recent_mentions, to: 'communications#find_recent_mentions'
        
        # Advanced Actions
        post :analyze_spending_pattern, to: 'financial#analyze_spending_pattern'
        post :get_conversation_history, to: 'communications#get_conversation_history'
        post :calculate_savings_potential, to: 'financial#calculate_savings_potential'
        post :discover_content_recommendations, to: 'content#discover_content_recommendations'
        
        # Specialized Actions
        post :analyze_health_trends, to: 'health#analyze_health_trends'
        post :find_favorite_media, to: 'content#find_favorite_media'
      end
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Dashboard route
  get "dashboard", to: "dashboard#index"

  authenticated :user do
    root "dashboard#index", as: :authenticated_user_root
  end

  # Defines the root path route ("/")
  root "pages#home"
end
