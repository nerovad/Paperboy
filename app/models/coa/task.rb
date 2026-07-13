# frozen_string_literal: true

module Coa
  class Task < BaseRecord
    self.table_name = 'tasks'
    self.primary_key = %i[agency_id task_id]

    belongs_to :agency, foreign_key: :agency_id, inverse_of: :tasks
  end
end
