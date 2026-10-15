# frozen_string_literal: true

require 'test_helper'

# AIM serves more than one agency (#131), so every AIM table says whose rows
# it holds: an agency column (agency or agency_id), an agency group
# (agency_group_id), or a budget unit, which belongs to exactly one group
# (Aim::AgencyGroups). A table whose rows belong to another row -- an
# invoice's events, a rule's history -- inherits that row's owner, and a few
# are shared on purpose. Those are listed here with the reason.
#
# A new aim table needs one of the columns, or a line below saying why not.
module Aim
  class AgencyScopeTest < ActiveSupport::TestCase
    SCHEMA = Rails.root.join('db/schema.rb').read.freeze
    OWNER_COLUMNS = %w[agency agency_id agency_group_id budget_unit].freeze

    EXEMPT = {
      'aim.coding_lines' => 'an invoice\'s coding: the invoice\'s agency',
      'aim.coding_rule_changes' => 'a rule\'s history: the rule\'s agency',
      'aim.fiscal_report_invoices' => 'a report\'s invoices: the report\'s agency group',
      'aim.fiscal_records' => 'an invoice\'s Fiscal record: the invoice\'s agency',
      'aim.invoice_events' => 'an invoice\'s history: the invoice\'s agency',
      'aim.members' => 'people, who work in units through aim.user_budget_units',
      'aim.user_preferences' => 'one person\'s own choices',
      'aim.vendor_aliases' => 'shared by every agency (Joshua, 2026-10-13)',
      'aim.vendor_rules' => 'shared by every agency (Joshua, 2026-10-13)'
    }.freeze

    # [[table, its create_table block], ...]
    def aim_tables = SCHEMA.scan(/^  create_table "(aim\.[^"]+)"(.*?)^  end$/m)

    test 'every aim table says whose rows it holds' do
      unowned = aim_tables.reject do |table, body|
        EXEMPT.key?(table) || OWNER_COLUMNS.any? { |column| body.include?(%(t.string "#{column}")) || body.include?(%(t.bigint "#{column}")) }
      end.map(&:first)

      assert_empty unowned, "Give these an agency, agency_group_id or budget_unit column, or list them in EXEMPT with why: #{unowned.join(', ')}"
    end

    test 'nothing is exempt that no longer exists' do
      tables = aim_tables.to_h

      assert_empty EXEMPT.keys - tables.keys, 'EXEMPT names a table db/schema.rb no longer has'
    end
  end
end
