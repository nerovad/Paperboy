# frozen_string_literal: true

module Aim
  # Fiscal Setup: one sidebar link for what Fiscal set once and change
  # rarely, shown as tabs across those pages, so the Fiscal menu keeps to
  # daily work. A new setup page is another tab here, not another menu line.
  module FiscalSetupHelper
    # [[label, path, controller], ...] this person sees: Report Templates and
    # Stamp Layouts; for a Group Admin who is not an AIM Admin, their Agency
    # Groups and Users & Queues too (AIM Admins reach those from Admin).
    def aim_fiscal_setup_tabs
      tabs = [['Report Templates', aim_report_templates_path, 'report_templates'],
              ['Stamp Layouts', aim_stamp_layouts_path, 'stamp_layouts']]
      return tabs unless aim_group_admin? && !aim_user_admin?

      tabs + [['Agency Groups', aim_agency_groups_path, 'agency_groups'], ['Users & Queues', aim_admin_path, 'admin']]
    end

    # Whether this page is one of them, for the sidebar and the tab row.
    def aim_fiscal_setup_page? = aim_fiscal_setup_tabs.any? { |_, _, controller| controller == controller_name }
  end
end
