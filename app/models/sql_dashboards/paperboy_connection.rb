# frozen_string_literal: true

module SqlDashboards
  # This environment's Paperboy database under the read-only login.
  class PaperboyConnection < ApplicationRecord
    self.abstract_class = true

    establish_connection(Database.read_only_config(ApplicationRecord)) if Database.credentials
  end
end
