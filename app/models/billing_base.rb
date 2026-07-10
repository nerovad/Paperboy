# frozen_string_literal: true

class BillingBase < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :billing, reading: :billing }
end
