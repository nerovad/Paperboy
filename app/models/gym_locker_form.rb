# frozen_string_literal: true

class GymLockerForm < ApplicationRecord
  include AuditableEdits

  validates :name, :email, presence: true
end
