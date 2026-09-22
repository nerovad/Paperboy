# frozen_string_literal: true

module Aim
  # Base for AIM's tables. They live in the aim SQL schema inside the
  # Paperboy database, so every table name is schema-qualified:
  # Aim::Invoice reads aim.invoices.
  class Record < ApplicationRecord
    self.abstract_class = true
    self.table_name_prefix = 'aim.'
  end
end
