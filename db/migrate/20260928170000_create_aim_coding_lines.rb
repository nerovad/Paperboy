# frozen_string_literal: true

# Coding lines (item b.2): what an invoice is charged to, one line normally
# and more for a split, filled from the coding rules or by a person. The
# coding fields Fiscal typed on fiscal_records (item f's first cut) move
# here; the invoice gains its agency (item k) and when it was coded.
class CreateAimCodingLines < ActiveRecord::Migration[8.1]
  MOVED = %w[bdo_do org_number fund department object_code dept_object activity function_code major_program program
             phase task split_amount remit_to].freeze

  def up
    add_column 'aim.invoices', :agency, :string, limit: 3
    add_column 'aim.invoices', :coded_at, :datetime
    add_index 'aim.invoices', :coded_at, name: 'index_aim_invoices_on_coded_at'

    create_table 'aim.coding_lines' do |t|
      t.bigint :invoice_id, null: false
      t.integer :line_no, null: false, default: 1
      t.decimal :amount, precision: 15, scale: 2
      t.string :encumbrance_type, limit: 10
      t.string :encumbrance_number, limit: 100
      t.string :ma_number, limit: 100
      t.string :vendor_code, limit: 50
      t.string :fund, limit: 20
      t.string :department, limit: 20
      t.string :org_number, limit: 20
      t.string :object_code, limit: 20
      t.string :dept_object, limit: 20
      t.string :activity, limit: 20
      t.string :function_code, limit: 20
      t.string :major_program, limit: 20
      t.string :program, limit: 20
      t.string :phase, limit: 20
      t.string :task, limit: 20
      t.bigint :coding_rule_id
      t.string :source, limit: 20, null: false, default: 'person'
      t.string :set_by, limit: 255
      t.text :warnings
      t.timestamps
    end
    add_index 'aim.coding_lines', %i[invoice_id line_no], unique: true, name: 'index_aim_coding_lines_on_invoice_and_line'

    move_fiscal_coding
    MOVED.each { |column| remove_column 'aim.fiscal_records', column }
  end

  def down
    add_column 'aim.fiscal_records', :bdo_do, :string, limit: 100
    add_column 'aim.fiscal_records', :org_number, :string, limit: 20
    add_column 'aim.fiscal_records', :fund, :string, limit: 20
    add_column 'aim.fiscal_records', :department, :string, limit: 20
    %w[object_code dept_object activity function_code major_program program phase task].each do |column|
      add_column 'aim.fiscal_records', column, :string, limit: 20
    end
    add_column 'aim.fiscal_records', :split_amount, :string, limit: 100
    add_column 'aim.fiscal_records', :remit_to, :string, limit: 255
    drop_table 'aim.coding_lines'
    remove_index 'aim.invoices', name: 'index_aim_invoices_on_coded_at'
    remove_column 'aim.invoices', :coded_at
    remove_column 'aim.invoices', :agency
  end

  private

  # Anything Fiscal already typed becomes that invoice's first line.
  def move_fiscal_coding
    coding = %w[fund department org_number object_code dept_object activity function_code major_program program phase task]
    rows = select_all("SELECT invoice_id, bdo_do, remit_to, updated_by, #{coding.join(', ')} FROM aim.fiscal_records " \
                      "WHERE COALESCE(bdo_do, #{coding.join(', ')}, remit_to) IS NOT NULL")
    rows.each do |row|
      type, number = row['bdo_do'].to_s.match(/\A([A-Za-z]{2,4})_?(.*)\z/)&.captures
      extra = { 'encumbrance_type' => type&.upcase, 'encumbrance_number' => number.presence, 'vendor_code' => row['remit_to'],
                'source' => 'fiscal', 'set_by' => row['updated_by'], 'invoice_id' => row['invoice_id'],
                'created_at' => Time.current, 'updated_at' => Time.current }
      values = coding.to_h { |c| [c, row[c]] }.merge(extra).compact
      execute "INSERT INTO aim.coding_lines (#{values.keys.join(', ')}) VALUES (#{values.values.map { |v| quote(v) }.join(', ')})"
    end
  end
end
