# frozen_string_literal: true

module Coa
  class Function < BaseRecord
    self.table_name = 'functions'
    self.primary_key = %i[agency_id function_id]

    belongs_to :agency, foreign_key: :agency_id, inverse_of: :functions
  end
end
