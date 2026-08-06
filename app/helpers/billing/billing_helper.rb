# frozen_string_literal: true

module Billing
  # Builds the system-admin navigation displayed in the Billing sidebar.
  module BillingHelper
    # Items appear in this order. Page items link to a screen. Action items
    # submit a POST after the shared confirmation modal is accepted.
    SIDEBAR_ITEMS = [
      { key: 'reporting_period', label: 'Reporting Period', route: :billing_reporting_period_path, page: true },
      { key: 'enable_billing', label: 'Enable Billing', route: :billing_billing_types_path, page: true },
      { key: 'run_monthly_billing', label: 'Run Billing', operation: 'run', page: true },
      { key: 'print_reports', label: 'Print Billing Reports', operation: 'print', page: true },
      { key: 'view_reports', label: 'View Billing Reports', route: :billing_reports_path, page: true },
      { key: 'email_reports', label: 'Email Billing Reports', operation: 'email', page: true }
    ].freeze

    def billing_sidebar_items
      return [] unless system_admin?

      SIDEBAR_ITEMS.map do |item|
        path = item[:operation] ? billing_monthly_report_path(item[:operation]) : public_send(item[:route])
        item.merge(path: path)
      end
    end
  end
end
