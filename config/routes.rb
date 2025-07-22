# Mount Sidekiq web UI in development
Rails.application.routes.draw do
  # Album routes
  resources :albums do
    member do
      patch :add_photo
      delete :remove_photo
      patch :set_cover
    end
  end
  # Short URL routes (must be before auth required routes)
  get "s/:token", to: "short_urls#show", as: :short_url
  
  # External album sharing routes (before auth required routes)
  get "shared/albums/:token", to: "external_albums#show", as: :external_album
  get "shared/albums/:token/password", to: "external_albums#password_form", as: :external_album_password
  post "shared/albums/:token/authenticate", to: "external_albums#authenticate", as: :external_album_authenticate
  
  # Family invitation acceptance routes (outside nested resources)
  get "invitations/:token", to: "family_invitations#show", as: :invitation
  patch "invitations/:token/accept", to: "family_invitations#accept", as: :accept_invitation
  patch "invitations/:token/decline", to: "family_invitations#decline", as: :decline_invitation
  # Family routes
  resources :families do
    member do
      get :members
      patch :leave
    end
    resources :invitations, controller: 'family_invitations', except: [:index, :show]
  end
  # Photo routes
  resources :photos do
    member do
      get :processing_status
    end
  end
  get "home/index"
  devise_for :users, controllers: { 
    registrations: 'registrations',
    sessions: 'sessions'
  }
  
  # Invite-based registration route (with token)
  get 'users/sign_up/:invitation_token', to: 'registrations#new', as: :invitation_signup

  # Profile routes
  resources :profiles, only: [:show]
  
  # Unified settings routes
  get 'settings', to: 'settings#show', as: :settings
  patch 'settings/profile', to: 'settings#update_profile', as: :update_profile_settings
  patch 'settings/account', to: 'settings#update_account', as: :update_account_settings
  delete 'settings/account', to: 'settings#destroy_account', as: :destroy_account_settings
  
  # Redirect old edit routes to unified settings
  get 'profiles/:id/edit', to: redirect('/settings')
  get 'users/edit', to: redirect('/settings')

  if Rails.env.development?
    require 'sidekiq/web'
    require 'sidekiq/cron/web'
    mount Sidekiq::Web => '/sidekiq'
  end
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
