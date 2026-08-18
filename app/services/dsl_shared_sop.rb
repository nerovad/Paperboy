# frozen_string_literal: true

require Rails.root.join('config/data_runner/dsl/shared/chart_of_accounts')

class DslSharedSop
  REGISTRY = {
    chart_of_accounts: DslSharedSops::CHART_OF_ACCOUNTS
  }.freeze

  def self.fetch!(name)
    REGISTRY.fetch(name)
  rescue KeyError
    raise KeyError, "Unknown shared SOP: #{name}"
  end
end
