# frozen_string_literal: true

# app/helpers/billing_helper.rb
#
# The Billing app's sidebar tools. These were buttons on the standalone
# /billing_tools page reached from the Paperboy sidebar; the page is gone and
# each entry is now available from the Billing sidebar. Monthly Billing opens
# its compute form; the remaining tools confirm before posting to the tools
# controller. Labels, confirm text and order live here.
module BillingHelper
  # In sidebar order. +route+ is the destination path helper, +page+ identifies
  # a full-page tool, and +dates+ says whether a modal collects a date range.
  #
  # Monthly report operations share Billing::MonthlyReportsController; Get Raw
  # Data retains its legacy action until its replacement workflow is designed.
  BILLING_TOOLS = [
    { key: 'raw_data', label: 'Get Raw Data',
      route: :backup_staging_billing_tools_path, dates: false,
      confirm: 'Run the raw data query?' },
    { key: 'run_monthly_billing', label: 'Run Billing', operation: 'run', page: true },
    { key: 'print_reports', label: 'Print Billing Reports', operation: 'print', page: true },
    { key: 'view_reports', label: 'View Billing Reports', route: :billing_reports_path, page: true },
    { key: 'email_reports', label: 'Email Billing Reports', operation: 'email', page: true }
  ].freeze

  # The sidebar's tools with their resolved +path+. Empty for anyone but a
  # system admin, which is
  # the same audience the old page allowed — Billing app access on its own does
  # not open these procs.
  def billing_tools
    return [] unless system_admin?

    BILLING_TOOLS.map do |tool|
      path = tool[:operation] ? billing_monthly_report_path(tool[:operation]) : public_send(tool[:route])
      tool.merge(path: path)
    end
  end
end
