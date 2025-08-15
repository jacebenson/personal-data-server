Rails.application.routes.draw do
  devise_for :users
  get "pages/home"

  # Category pages
  get "financial", to: "categories#financial"
  get "personal", to: "categories#personal"

  # Data uploads routes
  resources :data_uploads, only: [ :index ] do
    collection do
      # Ally Bank specific routes
      get :ally_bank_statements
      post :upload_ally_bank_statements
      get :view_ally_bank_statements

      # Investment routes
      get :fidelity_data
      post :upload_fidelity_data
      get :principal_investments
      post :upload_principal_investments
      get :view_investments
      delete :clear_investments

      # Social Security routes
      get :social_security_earnings
      post :upload_social_security_earnings
      get :view_social_security_earnings

      # Amazon shopping routes
      get :amazon_orders
      post :upload_amazon_orders
      get :view_amazon_orders
      delete :clear_amazon_orders

      # Communication routes
      get :communications
      post :upload_mbox
      post :upload_linkedin_messages
      get :view_communications
      get "view_communications/:id", to: "data_uploads#show_communication", as: :show_communication
      delete :clear_communications

      # Calendar routes (legacy - redirect to new calendar routes)
      get :calendars, to: redirect('/calendars')
      post :upload_ics_file, to: 'calendars#upload_ics_file'
      get :view_calendars, to: redirect('/calendars')
      get "view_calendars/:id", to: "calendars#show_event", as: :show_calendar_event
      get :new_calendar, to: redirect('/calendars/new')
      post :create_calendar, to: 'calendars#create'
      get "edit_calendar/:id", to: redirect { |params, _| "/calendars/#{params[:id]}/edit" }
      patch "update_calendar/:id", to: 'calendars#update'
      post :sync_calendar, to: 'calendars#sync'
      delete :clear_calendars, to: 'calendars#clear_all'
      delete "remove_calendar/:id", to: 'calendars#destroy'

      # Duplicate and account management
      get :manage_duplicates
      delete :remove_duplicates
      delete :remove_account_transactions
      delete :remove_all_transactions
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

  # Contact management routes
  resources :contacts, only: [:index, :show] do
    collection do
      post :upload_vcard
      post :upload_linkedin_connections
      delete :clear
      get :duplicates
      post :merge
      get :auto_merge
      post :auto_merge
    end
    
    member do
      get :show, as: 'contact'
    end
  end

  # Health data routes
  resources :health, only: [ :index ] do
    collection do
      get :import
      post :process_import
    end
  end

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
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker


  authenticated :user do
    root "data_uploads#index", as: :authenticated_user_root
  end

  # Defines the root path route ("/")
  root "pages#home"
end
