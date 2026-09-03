# frozen_string_literal: true

module Billing
  class DataRefresh < DataRunner::DataRefresh
    GROUPS = {
      'billing' => { label: 'Billing', default: true },
      'mail_center_and_warehousing' => { label: 'Mail Center and Warehousing', default: false }
    }.freeze
    GROUP_RUN_NAME = 'billing_data_refresh'
  end
end
