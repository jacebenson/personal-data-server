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

      # Calendar routes
      get :calendars
      post :upload_ics_file
      post :add_ics_url
      get :view_calendars
      get "view_calendars/:id", to: "data_uploads#show_calendar_event", as: :show_calendar_event
      delete :clear_calendars
      delete "remove_calendar/:calendar_name", to: "data_uploads#remove_calendar", as: :remove_calendar

      # Duplicate and account management
      get :manage_duplicates
      delete :remove_duplicates
      delete :remove_account_transactions
      delete :remove_all_transactions
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
