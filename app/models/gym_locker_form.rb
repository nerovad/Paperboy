class GymLockerForm < ApplicationRecord


  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true
end
