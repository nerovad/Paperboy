# frozen_string_literal: true

class SocialMediaForm < ApplicationRecord
  include AuditableEdits

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true
end
