# config/routes.rb
Rails.application.routes.draw do
  resources :parking_lot_submissions, only: [:new, :create]
  root "parking_lot_submissions#new"
namespace :api do
  get 'divisions', to: 'dropdowns#divisions'
  get 'departments', to: 'dropdowns#departments'
  get 'units', to: 'dropdowns#units'
end
end
