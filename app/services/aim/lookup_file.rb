# frozen_string_literal: true

require 'csv'

module Aim
  # Reads one of Fiscal's lookup CSVs into rows with one set of column names,
  # whatever the file called them (item b). Eleven files, three layouts, read
  # 2026-09-23 and 2026-09-28; the known slips are put right here, each noted
  # on the row: an object with its description appended ("2192 TEMP HELP"), a
  # vendor code in the Fund column (Fleet, Parks), an underscore before a
  # fund ("_S040"), a keyword that is an MA number.
  class LookupFile
    # The template's own headings come first; the rest are what Fiscal's
    # files have called the same things.
    TEMPLATE = ['Vendor Name', 'Customer Number', 'Budget Unit', 'BDO / DO', 'MA Number', 'Vendor Code', 'Fund',
                'Department', 'Object', 'Activity', 'Function', 'Major Program', 'Program', 'Phase', 'Task', 'Notes'].freeze
    EXAMPLE = ['ACME Supply Co', '', '4641', 'BDO_46402026072600000012_1', 'ACMESUPPLYFY27MA01', 'VC00012345', 'G001',
               '', '2162', 'GATV', 'GFUN', '', 'INDIRECT', '', '', 'Any note for Fiscal'].freeze
    # A download of existing rules carries their ids, so a re-upload edits
    # those rules rather than adding beside them.
    EXPORT = (TEMPLATE + ['Rule ID']).freeze
    COLUMNS = {
      'rule id' => 'rule_id', 'vendor name' => 'vendor_name', 'vendor name lookup' => 'vendor_alt', 'customers' => 'customer_number',
      'customer number' => 'customer_number', 'ma number' => 'ma_number', 'bdo / do' => 'encumbrance',
      'account number' => 'customer_number', 'fiscal unique identifier' => 'vendor_code',
      'vendor code' => 'vendor_code', 'remit to' => 'vendor_code', 'fund' => 'fund', 'department' => 'department',
      'encumbrance doc (bdo, do, etc)' => 'encumbrance', 'bdo/po #' => 'encumbrance', 'bdo/do' => 'encumbrance',
      'budget unit' => 'budget_unit', 'budget unit #' => 'budget_unit', 'unit' => 'budget_unit',
      'object' => 'object_code', 'activity' => 'activity', 'function' => 'function_code', 'program' => 'program',
      'major program' => 'major_program', 'phase' => 'phase', 'task' => 'task', 'keywords' => 'keyword',
      'keyword' => 'keyword', 'notes' => 'notes', 'notes -final approver' => 'notes',
      'approver name' => 'approver', 'fusion queue' => 'queue', 'aim unique identifier' => 'aim_id'
    }.freeze
    VENDOR_CODE = /\AV[CS]\d{6,}\z/i
    MA_NUMBER = /FY\d{2}MA\d+\z/i

    Row = Struct.new(:number, :fields, :notes, keyword_init: true)

    # The date in an encumbrance number: BDO_4700 20240729 ... is that day;
    # CT_4620 FY23 ... is that fiscal year's first day. Nil when neither.
    def self.date_in(number)
      digits = number.to_s.sub(/\A\d{4}/, '')
      if (m = digits.match(/\A(20\d{2})(\d{2})(\d{2})/))
        Date.new(m[1].to_i, m[2].to_i, m[3].to_i)
      elsif (m = digits.match(/\AFY(\d{2})/i))
        Date.new(2000 + m[1].to_i - 1, 7, 1)
      end
    rescue Date::Error
      nil
    end

    attr_reader :rows, :unknown_columns

    def initialize(path)
      table = CSV.read(path, encoding: 'bom|utf-8', liberal_parsing: true)
      header = table.shift.to_a.map { |name| name.to_s.strip.downcase }
      @columns = header.each_with_index.filter_map { |name, index| [COLUMNS[name], index] if COLUMNS[name] }
      @unknown_columns = header.reject { |name| name.blank? || COLUMNS.key?(name) }
      @rows = table.each_with_index.filter_map do |cells, index|
        next if cells.all? { |cell| cell.to_s.strip.empty? }

        row(index + 2, cells)
      end
    end

    private

    # The first filled cell under each name (a file may repeat a heading).
    def row(number, cells)
      values = {}
      @columns.each do |name, index|
        value = Paperboy::CsvSafe.restore(cells[index]).strip
        values[name] = value if value.present? && values[name].blank?
      end
      notes = []
      tidy(values, notes)
      Row.new(number: number, fields: values, notes: notes)
    end

    def tidy(values, notes)
      if values['object_code'].to_s.match?(/\A\d{4}\s+\S/)
        notes << "object read from #{values['object_code'].inspect}"
        values['object_code'] = values['object_code'][/\A\d{4}/]
      end
      if values['fund'].to_s.match?(VENDOR_CODE)
        notes << 'vendor code found in the Fund column'
        code = values.delete('fund')
        values['vendor_code'] ||= code
      end
      values['fund'] = values['fund'].delete_prefix('_') if values['fund']&.start_with?('_')
      type, number = Aim::CodingFields.split_encumbrance(values.delete('encumbrance').to_s.upcase)
      values.merge!('encumbrance_type' => type, 'encumbrance_number' => number) if type
      keyword = values.delete('keyword')
      if values['ma_number'].present?
        values['notes'] = [values['notes'], "keyword: #{keyword}"].compact.join('; ') if keyword
      elsif keyword&.match?(MA_NUMBER)
        values['ma_number'] = keyword
      elsif keyword
        values['notes'] = [values['notes'], "keyword: #{keyword}"].compact.join('; ')
      end
      values.delete('vendor_alt')
    end
  end
end
