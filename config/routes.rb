require 'sidekiq/web'

Rails.application.routes.draw do
  get "forms/home"
  mount Sidekiq::Web => '/sidekiq'

  root "forms#home"

  resources :parking_lot_submissions, only: [:new, :create, :index] do
    member do
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

