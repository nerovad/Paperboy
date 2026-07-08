module Coa
  class Object < BaseRecord
    self.table_name = "objects"
    self.primary_key = :object_id

    has_many :object_inferences, foreign_key: :object_id, inverse_of: :object
  end
end
