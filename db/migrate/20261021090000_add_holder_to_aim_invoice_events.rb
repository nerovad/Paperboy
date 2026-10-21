# frozen_string_literal: true

# Who held an invoice after each event (#190): the employee and name of the
# person whose queue it was in -- none for a BU's shared queue -- and its
# budget unit. An event used to name the holder only in its note ("moved from
# X to Y"), so how long an invoice sat with each person could not be counted,
# and a late invoice handed on looked like the last holder's.
#
# holder_source says how the row learned it: 'recorded' when the event was
# written (Aim::InvoiceEvent, the worker's Db), 'inferred' when
# rake aim:backfill_event_holders read it from the history, NULL when nobody
# knows. Older rows are left NULL here; the backfill fills what it can.
#
# Indexed for the reports' "time with each person" (holder, then when).
# Explicit index name: see test/lib/aim/schema_conventions_test.rb. A second
# run, or a run after a crash, adds only what is missing.
class AddHolderToAimInvoiceEvents < ActiveRecord::Migration[8.1]
  COLUMNS = {
    holder_employee_id: [:integer, {}],
    holder_name: [:string, { limit: 255 }],
    holder_budget_unit: [:string, { limit: 10 }],
    holder_source: [:string, { limit: 20 }]
  }.freeze

  def up
    COLUMNS.each do |name, (type, options)|
      add_column 'aim.invoice_events', name, type, **options unless column_exists?('aim.invoice_events', name)
    end
    add_index 'aim.invoice_events', %i[holder_employee_id created_at],
              name: 'index_aim_invoice_events_on_holder_and_created_at', if_not_exists: true
  end

  def down
    remove_index 'aim.invoice_events', name: 'index_aim_invoice_events_on_holder_and_created_at', if_exists: true
    COLUMNS.each_key { |name| remove_column 'aim.invoice_events', name if column_exists?('aim.invoice_events', name) }
  end
end
