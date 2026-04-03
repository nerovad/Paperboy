class GsabssBase < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :gsabss, reading: :gsabss }
end
