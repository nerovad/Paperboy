# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :user  # Stores session[:user] hash
end
