# frozen_string_literal: true

# Free-text search across a Records table (see Registry). The query is matched
# against the value of every column the table declares -- the same reader the
# grid renders (`row.public_send(name)`) -- so derived cells such as a fleet
# vehicle's "Assigned To" (owner_name, read through the garaging form) or a
# status label are searchable alongside the stored columns.
#
# Matching happens in Ruby over rows that are already loaded, because derived
# cells have no SQL counterpart to put in a WHERE. The records grid loads its
# whole row set to filter and sort in memory anyway, so this adds no query.
#
# Encrypted columns are skipped: their reader returns the decrypted value, and
# a free-text box must not let someone probe a card number digit by digit.
module RecordsSearch
  module_function

  # Names of the columns a query is matched against, as strings.
  def searchable_columns(table)
    model = table.model

    table.columns.map { |column| column.name.to_s }.uniq.reject do |name|
      RecordsEditing.encrypted?(model, name)
    end
  end

  # The rows whose searchable cells contain `query`, case-insensitively. A
  # blank query, or a table with nothing searchable on it, keeps every row.
  def apply(table, rows, query)
    needle = query.to_s.strip.downcase
    return rows.to_a if needle.blank?

    names = searchable_columns(table)
    return rows.to_a if names.empty?

    rows.select do |row|
      names.any? { |name| row.public_send(name).to_s.downcase.include?(needle) }
    end
  end
end
