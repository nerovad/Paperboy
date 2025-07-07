# config/routes.rb
Rails.application.routes.draw do
  resources :parking_lot_submissions, only: [:new, :create]
  root "parking_lot_submissions#new"
end

