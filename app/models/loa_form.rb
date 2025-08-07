class LoaForm < ApplicationRecord
  self.table_name = "loa_forms"

  belongs_to :event, optional: true
end
