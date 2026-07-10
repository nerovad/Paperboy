# frozen_string_literal: true

module DataRunner
  class Employee < ApplicationRecord
    self.table_name = "Employees"
    self.primary_key = "id"
    self.inheritance_column = nil

    alias_attribute :employee_id, :id
  end
end
