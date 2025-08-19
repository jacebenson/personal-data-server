Rails.application.routes.draw do
  devise_for :users
  get "pages/home"

  # Category pages
  get "financial", to: "financial#index"
  get "personal", to: "personal#index"
  get "entertainment", to: "entertainment#index"
  get "shopping", to: "shopping#index"

  # Legacy data_uploads routes - redirected to appropriate controllers
  resources :data_uploads, only: [:index] do
    collection do
      # Redirect to dashboard
      get '', to: redirect('/dashboard')
      
      # Financial redirects
      get :ally_bank_statements, to: redirect('/financial/bank_statements')
      post :upload_ally_bank_statements, to: redirect('/financial/upload_bank_statements')
      get :view_ally_bank_statements, to: redirect('/financial/view_bank_statements')
      get :fidelity_data, to: redirect('/financial/fidelity_upload')
      post :upload_fidelity_data, to: redirect('/financial/upload_fidelity_data')
      get :principal_investments, to: redirect('/financial/principal_upload')
      post :upload_principal_investments, to: redirect('/financial/upload_principal_data')
      get :view_investments, to: redirect('/financial/view_investments')
      get :manage_duplicates, to: redirect('/financial/manage_duplicates')
      delete :clear_investments, to: redirect('/financial/clear_investments')

      # Shopping redirects
      get :amazon_orders, to: redirect('/shopping/upload')
      post :upload_amazon_orders, to: redirect('/shopping/upload_orders')
      get :view_amazon_orders, to: redirect('/shopping/view_orders')
      delete :clear_amazon_orders, to: redirect('/shopping/clear_orders')

      # Other legacy redirects
      get :social_security_earnings, to: redirect('/social_security')
      post :upload_social_security_earnings, to: 'social_security#upload_earnings'
      get :view_social_security_earnings, to: redirect('/social_security/view_earnings')
      get :communications, to: redirect('/communications')
      post :upload_mbox, to: 'communications#upload_mbox'
      post :upload_linkedin_messages, to: 'communications#upload_linkedin_messages'
      get :view_communications, to: redirect('/communications/view')
      get "view_communications/:id", to: redirect { |params, _| "/communications/#{params[:id]}" }
      delete :clear_communications, to: 'communications#clear'
      get :entertainment, to: redirect('/entertainment')
      get :netflix, to: redirect('/entertainment/netflix')
      post :upload_netflix, to: 'entertainment#upload_netflix'
      get :view_netflix, to: redirect('/entertainment/view_netflix')
      delete :clear_netflix, to: 'entertainment#clear_netflix'
      get :youtube, to: redirect('/entertainment/youtube')
      post :upload_youtube, to: 'entertainment#upload_youtube'
      get :view_youtube, to: redirect('/entertainment/view_youtube')
      delete :clear_youtube, to: 'entertainment#clear_youtube'
      delete :remove_duplicates, to: redirect('/financial/remove_duplicates')
      delete :remove_account_transactions, to: redirect('/financial/clear_bank_statements')
      delete :remove_all_transactions, to: redirect('/financial/clear_bank_statements')
      post :add_balance_adjustment, to: 'financial#add_balance_adjustment'
    end
  end

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
  resources :entertainment, only: [:index] do
    collection do
      get :netflix
      post :upload_netflix
      get :view_netflix
      delete :clear_netflix
      
      # YouTube watch history
      get :youtube
      post :upload_youtube
      get :view_youtube
      delete :clear_youtube
      
      # Audible listening history
      get :audible
      post :upload_audible
      get :view_audible
      delete :clear_audible
      
      # Audible library
      get :audible_library
      post :upload_audible_library
      get :view_audible_library
      delete :clear_audible_library
      
      # Podcast feed management
      get :podcasts
      post :upload_opml
      post :add_podcast_feed
      delete :clear_podcast_feeds
      
      # Podcast episode views
      get 'podcast/:id', to: 'entertainment#podcast_episodes', as: :podcast_episodes
      get 'podcast/:podcast_id/episode/:id', to: 'entertainment#podcast_episode', as: :podcast_episode
      patch 'podcast/:podcast_id/episode/:id/toggle_listened', to: 'entertainment#toggle_episode_listened', as: :toggle_episode_listened
      get :all_episodes
    end
    
    member do
      post :sync_podcast_feed
      patch :toggle_podcast_feed
      delete :delete_podcast_feed
    end
  end
  
  # Podcast feed sync route (for syncing all)
  post 'entertainment/sync_all_podcast_feeds', to: 'entertainment#sync_all_podcast_feeds'

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
