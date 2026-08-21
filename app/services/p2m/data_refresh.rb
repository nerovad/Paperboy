# frozen_string_literal: true

module P2m
  class DataRefresh < DataRunner::DataRefresh
    GROUPS = {
      'print_2_mail' => { label: 'Print 2 Mail', default: false },
      'print_2_mail_billing_data' => { label: 'Print 2 Mail Billing Data', default: true }
    }.freeze
    GROUP_RUN_NAME = 'p2m_data_refresh'
  end
end
