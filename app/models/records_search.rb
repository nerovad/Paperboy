# frozen_string_literal: true

# Free-text search across a Records table (see Registry). The query is matched
# against every column the table declares that is backed by a real string/text
# column on the model. Derived cells are skipped because they have nothing to
# match in SQL (status_label, masked_card_number and owner_name are methods),
# and so are encrypted columns, whose stored ciphertext a plaintext query can
# never hit.
#
# Conditions are built through Arel so column names stay quoted and the query
# value stays a bound parameter — the column list is already constrained to the
# model's own columns_hash, and nothing user-supplied reaches the SQL string.
module RecordsSearch
  SEARCHABLE_TYPES = %i[string text].freeze

  module_function

  # Names of the columns a query is matched against, as strings.
  def searchable_columns(table)
    model = table.model

    table.columns.map { |column| column.name.to_s }.uniq.select do |name|
      column = model.columns_hash[name]
      column && SEARCHABLE_TYPES.include?(column.type) && !RecordsEditing.encrypted?(model, name)
    end
  end

  # Narrow `scope` to the rows matching `query`. A blank query, or a table with
  # nothing searchable on it, leaves the scope untouched.
  def apply(table, scope, query)
    query = query.to_s.strip
    return scope if query.blank?

    names = searchable_columns(table)
    return scope if names.empty?

    arel = table.model.arel_table
    scope.where(names.map { |name| arel[name].matches("%#{query}%") }.reduce(:or))
  end
end
