# frozen_string_literal: true

module HumanResources
  # The Human Resources refresh screen runs the Data Runner human_resources
  # group. The run name stays separate so that group's own refresh, started
  # from Data Runner, is a different GroupRun.
  class DataRefresh < DataRunner::DataRefresh
    GROUPS = {
      'human_resources' => { label: 'Human Resources', default: true }
    }.freeze
    GROUP_RUN_NAME = 'human_resources_data_refresh'
  end
end
