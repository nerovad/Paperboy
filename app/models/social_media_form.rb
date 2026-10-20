# frozen_string_literal: true

class SocialMediaForm < ApplicationRecord
  include AuditableEdits

  validates :name, :email, presence: true
end
