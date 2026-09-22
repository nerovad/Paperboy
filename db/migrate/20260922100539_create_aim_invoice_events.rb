# frozen_string_literal: true

# The history of every AIM invoice: who moved it, from which state to which,
# and when. Append-only -- rows are written and never changed -- so it is the
# audit trail the pipeline has never had.
class CreateAimInvoiceEvents < ActiveRecord::Migration[8.1]
  def change
    create_table 'aim.invoice_events' do |t|
      # No database foreign key, deliberately: the SQL Server adapter dumps
      # one on a schema-qualified table without its schema, and the broken
      # schema.rb then fails every test database build. Aim::InvoiceEvent's
      # belongs_to and Aim::Invoice's restrict_with_exception hold the link.
      t.references :invoice, null: false, index: false
      # What happened. A state change is a transition; 5.4 onwards may add
      # others, such as a claim or an assignment.
      t.string :action, null: false, limit: 50
      t.string :from_state, limit: 50
      t.string :to_state, limit: 50
      # A person's email, or the name of the worker that did it.
      t.string :actor, null: false
      t.text :note
      t.datetime :created_at, null: false
    end

    add_index 'aim.invoice_events', %i[invoice_id created_at], name: 'index_aim_invoice_events_on_invoice_id_and_created_at'
  end
end
