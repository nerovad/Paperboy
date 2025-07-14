require 'sidekiq/web'

Rails.application.routes.draw do
  resources :probation_transfer_requests
  get "forms/home"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"
  mount Sidekiq::Web => '/sidekiq'

  root "forms#home"

  resources :parking_lot_submissions, only: [:new, :create, :index] do
    member do
      get :pdf
      patch :approve
      patch :deny
    end
  end

    namespace :api do
    get 'divisions', to: 'dropdowns#divisions'
    get 'departments', to: 'dropdowns#departments'
    get 'units', to: 'dropdowns#units'
  end
end
