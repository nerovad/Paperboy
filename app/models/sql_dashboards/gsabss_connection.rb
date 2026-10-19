# frozen_string_literal: true

module SqlDashboards
  # GSABSS under the read-only login.
  class GsabssConnection < ApplicationRecord
    self.abstract_class = true

    establish_connection(Database.read_only_config(GsabssBase)) if Database.credentials
  end
end
