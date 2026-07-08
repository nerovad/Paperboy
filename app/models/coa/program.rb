module Coa
  class Program < BaseRecord
    self.table_name = "programs"
    self.primary_key = %i[agency_id program_id major_program_id]

    belongs_to :agency, foreign_key: :agency_id, inverse_of: :programs
    belongs_to :major_program,
               foreign_key: %i[agency_id major_program_id],
               inverse_of: :programs
  end
end
