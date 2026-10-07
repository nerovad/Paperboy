# frozen_string_literal: true

# The rows of one Records email, in the shape RecordsCsv writes: the table, its
# default columns and the rows. A grid view carries a person's own column
# layout; a rule's email goes to people who may never have opened the grid, so
# it uses the table's.
RecordsEmailSheet = Struct.new(:table, :rows) do
  def columns
    @columns ||= TableColumns.resolve(table.page_key, TableColumns.default_layout(table.page_key))
  end

  def to_csv = RecordsCsv.generate(self)
end
