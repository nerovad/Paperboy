# app/models/authorization_form.rb
class AuthorizationForm < ApplicationRecord
  # Keep validations as light as you want
  validates :name, :email, presence: true, allow_blank: false
end
