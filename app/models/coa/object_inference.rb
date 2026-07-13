# frozen_string_literal: true

module Coa
  class ObjectInference < BaseRecord
    self.table_name = "agency_objects"
    self.primary_key = %i[agency_id agency_object_code]

    belongs_to :agency, foreign_key: :agency_id, inverse_of: :object_inferences
    belongs_to :object, foreign_key: :object_id, inverse_of: :object_inferences, optional: true
  end
end
