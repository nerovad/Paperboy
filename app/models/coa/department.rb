# frozen_string_literal: true

module Coa
  class Department < BaseRecord
    self.table_name = 'departments'
    self.primary_key = %i[agency_id division_id department_id]

    belongs_to :agency, foreign_key: :agency_id, inverse_of: :departments
    belongs_to :division, foreign_key: %i[agency_id division_id], inverse_of: :departments

    has_many :units, foreign_key: %i[agency_id division_id department_id], inverse_of: :department
  end
end
