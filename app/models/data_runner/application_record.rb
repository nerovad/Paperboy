# frozen_string_literal: true

module DataRunner
  # Plain abstract base, not `primary_abstract_class` — that role belongs to
  # Paperboy's top-level ApplicationRecord, and Rails permits only one. This
  # class was DataRunner's primary back when DataRunner was its own app.
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
