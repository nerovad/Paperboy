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
  # Get Raw Data, Print Reports and Email Reports post to backup_staging: that
  # is placeholder wiring carried over verbatim from the old page rather than
  # silently repointed. They need their own actions once the procs exist.
  BILLING_TOOLS = [
    { key: 'raw_data', label: 'Get Raw Data', section: 'Data & Backups',
      route: :backup_staging_billing_tools_path, dates: false,
      confirm: 'Run the raw data query?' },
    { key: 'backup_staging', label: 'Backup Staging', section: 'Data & Backups',
      route: :backup_staging_billing_tools_path, dates: false,
      confirm: 'Create a fresh backup of the staging database?' },
    { key: 'backup_production', label: 'Backup Production', section: 'Data & Backups',
      route: :backup_production_billing_tools_path, dates: false,
      confirm: 'Back up the production database? This may take a while.' },
    { key: 'run_monthly_billing', label: 'Run Monthly Billing', section: 'Billing & Reports',
      route: :monthly_billing_billing_tools_path, page: true },
    { key: 'print_reports', label: 'Print Reports', section: 'Billing & Reports',
      route: :backup_staging_billing_tools_path, dates: true,
      confirm: 'Generate and print billing reports for this period?' },
    { key: 'email_reports', label: 'Email Reports', section: 'Billing & Reports',
      route: :backup_staging_billing_tools_path, dates: true,
      confirm: 'Email billing reports for this period?' }
  ].freeze

  # The sidebar's tool buttons as { section title => [tool, ...] }, each tool
  # carrying the resolved +path+. Empty for anyone but a system admin, which is
  # the same audience the old page allowed — Billing app access on its own does
  # not open these procs.
  def billing_tool_sections
    return {} unless system_admin?

    BILLING_TOOLS.group_by { |tool| tool[:section] }
                 .transform_values { |tools| tools.map { |tool| tool.merge(path: public_send(tool[:route])) } }
  end
end
