# app/models/gsabss_base.rb
class GsabssBase < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :gsabss }
end
