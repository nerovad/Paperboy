# Runtime resolver for the form builder's generic ("custom") dropdown data
# source. Generated form views call FormLookup.options(field_id) with ONLY an
# integer, so no user-supplied strings ever reach generated code on disk.
#
# All table/column names are validated against the live schema and passed
# through the adapter's identifier quoting before they touch SQL; the category
# filter value is bound via #quote. GSABSS is read-only and we only SELECT.
class FormLookup
  # Logical database name -> ActiveRecord base class that owns the connection.
  # "paperboy" auto-resolves to Paperboy_Dev/Stage/Prod by environment;
  # "gsabss" is the read-only reference DB (GsabssBase).
  CONNECTIONS = {
    "paperboy" => ApplicationRecord,
    "gsabss"   => GsabssBase
  }.freeze

  # Connection for a logical database name, or nil if the name is unknown.
  def self.connection_for(database)
    CONNECTIONS[database.to_s]&.connection
  end

  # True if `table` exists as a base table or view on the given connection.
  def self.table_exists_in?(conn, table)
    return false if table.blank?
    conn.tables.include?(table) ||
      (conn.respond_to?(:views) && conn.views.include?(table))
  end

  # Synthetic (computed) columns a table exposes for answer lookups on top of its
  # real columns. Only the employees "full_name" (Last, First) key today, which
  # mirrors how employee dropdowns render their option labels.
  def self.synthetic_columns(table)
    table.to_s == "employees" ? %w[full_name] : []
  end

  # Answer-lookup autofill. Given target field IDs that share one trigger field
  # and the trigger's selected display text, return { field_id => filled_value }.
  # Fields are grouped by [database, table, match_column] so one query per group
  # fills many fields. All identifiers are validated against the live schema and
  # quoted; the match value is bound via #quote. Returns {} on any failure so a
  # bad config or unreachable DB can never 500 a live form.
  def self.answer_fills(field_ids, value)
    return {} if value.to_s.strip.empty?

    fields = FormField.where(id: field_ids).select(&:answer_lookup?)
    return {} if fields.empty?

    result = {}
    fields.group_by { |f| f.answer_lookup_config.values_at("database", "table", "match_column") }
          .each do |(database, table, match_column), group|
      conn = connection_for(database)
      next unless conn && table_exists_in?(conn, table)

      columns   = conn.columns(table).map(&:name)
      synthetic = synthetic_columns(table)
      row = matched_row(conn, table, match_column, value, columns, synthetic)
      next unless row

      group.each do |field|
        cfg = field.answer_lookup_config
        filled = combined_value(
          table, cfg["return_column"], cfg["return_join_columns"],
          cfg["return_join_separator"], row, columns, synthetic
        )
        result[field.id] = filled unless filled.nil? || filled.to_s.empty?
      end
    end
    result
  rescue => e
    Rails.logger.error("FormLookup.answer_fills failed: #{e.class}: #{e.message}")
    {}
  end

  # Fetch the single row matching `value` on `match_column`. Supports the
  # employees "full_name" synthetic key by splitting "Last, First" and matching
  # last_name/first_name. Returns a column=>value Hash or nil. SQL Server only.
  def self.matched_row(conn, table, match_column, value, columns, synthetic)
    qt = conn.quote_table_name(table)

    where_sql =
      if synthetic.include?(match_column) && table == "employees" && match_column == "full_name"
        last, first = value.to_s.split(", ", 2)
        return nil if last.to_s.empty?
        clauses = [ "#{conn.quote_column_name('last_name')} = #{conn.quote(last)}" ]
        clauses << "#{conn.quote_column_name('first_name')} = #{conn.quote(first)}" if first.present?
        clauses.join(" AND ")
      elsif columns.include?(match_column)
        "#{conn.quote_column_name(match_column)} = #{conn.quote(value)}"
      end
    return nil unless where_sql

    conn.exec_query("SELECT TOP 1 * FROM #{qt} WHERE #{where_sql}").first
  end

  # Build the fill value by combining the primary return column with any extra
  # "join" columns from the same row, in order, separated by `sep` (default a
  # space). Mirrors the join_columns/join_separator option-source pattern. The
  # employees "full_name" synthetic key is still honored for back-compat.
  def self.combined_value(table, primary, join_cols, sep, row, columns, synthetic)
    sep = " " unless sep.is_a?(String) && !sep.empty?

    # The primary value may be a synthetic column (e.g. employees "full_name");
    # the "+ also" join columns are always real columns from the same row.
    primary_value =
      if synthetic.include?(primary)
        synthesize(table, primary, row)
      elsif columns.include?(primary)
        row[primary]
      end

    join_values = Array(join_cols).select { |c| columns.include?(c) }.map { |c| row[c] }
    ([ primary_value ] + join_values).reject { |v| v.nil? || v.to_s.empty? }.join(sep)
  end

  # Build a synthetic column's value from a fetched row.
  def self.synthesize(table, column, row)
    return nil unless table == "employees" && column == "full_name"
    "#{row['last_name']}, #{row['first_name']}"
  end
  private_class_method :matched_row, :combined_value, :synthesize

  # Distinct option values (value == label) for a custom-lookup field, ordered.
  # Returns [] for non-custom fields or any invalid/failed config so a bad
  # setting can never 500 a live form.
  def self.options(field_id)
    field = FormField.find_by(id: field_id)
    return [] unless field&.custom_lookup?

    cfg  = field.custom_lookup_config
    conn = connection_for(cfg["database"])
    return [] unless conn
    return [] unless table_exists_in?(conn, cfg["table"])

    table   = cfg["table"]
    columns = conn.columns(table).map(&:name)
    col     = cfg["column"]
    return [] unless columns.include?(col)

    # The chosen column plus any "join" columns are concatenated into each
    # option's value/label, in order, so e.g. first_name + last_name display
    # together. Unknown columns are silently dropped; the primary column leads.
    join_cols    = Array(cfg["join_columns"]).select { |c| c.present? && columns.include?(c) }
    display_cols = ([ col ] + join_cols).uniq
    sep          = cfg["join_separator"]
    sep          = " " unless sep.is_a?(String) && !sep.empty?

    order_col = cfg["order_column"].presence
    order_col = nil unless order_col && columns.include?(order_col)

    qt = conn.quote_table_name(table)
    # Project each display column under a stable alias (c0, c1, …) so the row
    # values can be re-joined in Ruby regardless of the real column names.
    select_aliases = display_cols.each_index.map do |i|
      "#{conn.quote_column_name(display_cols[i])} AS #{conn.quote_column_name("c#{i}")}"
    end

    # Category filters narrow the result set. Multiple values picked for the SAME
    # column are OR'd (an IN list); filters on DIFFERENT columns are AND'd. So
    # site=Clinic/Office/Hospital matches any of the three, and adding agency=HCA
    # further requires that agency. Unknown columns and blank values are skipped;
    # values are bound via #quote.
    grouped = field.custom_lookup_category_filters.each_with_object({}) do |f, h|
      fcol = f["column"]
      fval = f["value"]
      next unless columns.include?(fcol)
      next if fval.nil? || fval.to_s.empty?
      (h[fcol] ||= []) << fval
    end
    clauses = grouped.map do |fcol, vals|
      qcol = conn.quote_column_name(fcol)
      vals = vals.uniq
      if vals.size == 1
        "#{qcol} = #{conn.quote(vals.first)}"
      else
        "#{qcol} IN (#{vals.map { |v| conn.quote(v) }.join(", ")})"
      end
    end
    where_sql = clauses.any? ? " WHERE #{clauses.join(" AND ")}" : ""

    # Direction is a fixed keyword (never interpolated raw). Ascending/descending
    # is the only knob needed — numeric vs alphabetical follows the column type.
    dir = cfg["order_direction"].to_s.downcase == "desc" ? "DESC" : "ASC"

    # SQL Server requires every ORDER BY column to appear in a DISTINCT select
    # list. The display columns are always projected; carry the order column
    # along only when it isn't one of them.
    if order_col && !display_cols.include?(order_col)
      qo          = conn.quote_column_name(order_col)
      select_list = (select_aliases + [ "#{qo} AS sort_val" ]).join(", ")
      order_by    = "#{qo} #{dir}"
    else
      select_list = select_aliases.join(", ")
      order_by    = "#{conn.quote_column_name(order_col || display_cols.first)} #{dir}"
    end

    sql = "SELECT DISTINCT #{select_list} FROM #{qt}#{where_sql} ORDER BY #{order_by}"

    conn.exec_query(sql).map do |row|
      display_cols.each_index
                  .map { |i| row["c#{i}"] }
                  .reject { |v| v.nil? || v.to_s.empty? }
                  .join(sep)
    end.reject(&:empty?).uniq
  rescue => e
    Rails.logger.error("FormLookup.options(#{field_id}) failed: #{e.class}: #{e.message}")
    []
  end
end
