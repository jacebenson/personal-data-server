Rails.application.routes.draw do
  devise_for :users
  get "pages/home"

  # Data uploads routes
  resources :data_uploads, only: [ :index ] do
    collection do
      get :ally_bank_statements
      post :upload_ally_bank_statements
      get :view_ally_bank_statements
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
