module Coa
  class Activity < BaseRecord
    self.table_name = 'activities'
    self.primary_key = %i[agency_id activity_id]

    belongs_to :agency, foreign_key: :agency_id, inverse_of: :activities
  end
end
