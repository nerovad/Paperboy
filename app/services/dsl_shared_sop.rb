# frozen_string_literal: true

require Rails.root.join('config/data_runner/dsl/shared/chart_of_accounts')
require Rails.root.join('config/data_runner/dsl/shared/p2m_billing')
require Rails.root.join('config/data_runner/dsl/shared/print_2_mail')

class DslSharedSop
  REGISTRY = {
    chart_of_accounts: DslSharedSops::CHART_OF_ACCOUNTS,
    p2m_billing: DslSharedSops::P2M_BILLING,
    print_2_mail: DslSharedSops::PRINT_2_MAIL
  }.freeze

  def self.fetch!(name)
    REGISTRY.fetch(name)
  rescue KeyError
    raise KeyError, "Unknown shared SOP: #{name}"
  end
end
