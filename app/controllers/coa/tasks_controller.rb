# frozen_string_literal: true

module Coa
  class TasksController < CrudController
    self.coa_model_class = Coa::Task
  end
end
