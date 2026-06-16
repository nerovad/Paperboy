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
    display_cols = ([col] + join_cols).uniq
    sep          = cfg["join_separator"]
    sep          = " " unless sep.is_a?(String) && !sep.empty?

    cat_col   = cfg["category_column"].presence
    cat_col   = nil unless cat_col && columns.include?(cat_col)
    order_col = cfg["order_column"].presence
    order_col = nil unless order_col && columns.include?(order_col)

    qt = conn.quote_table_name(table)
    # Project each display column under a stable alias (c0, c1, …) so the row
    # values can be re-joined in Ruby regardless of the real column names.
    select_aliases = display_cols.each_index.map do |i|
      "#{conn.quote_column_name(display_cols[i])} AS #{conn.quote_column_name("c#{i}")}"
    end

    where_sql = ""
    if cat_col && cfg["category_value"].present?
      where_sql = " WHERE #{conn.quote_column_name(cat_col)} = #{conn.quote(cfg["category_value"])}"
    end

    # Direction is a fixed keyword (never interpolated raw). Ascending/descending
    # is the only knob needed — numeric vs alphabetical follows the column type.
    dir = cfg["order_direction"].to_s.downcase == "desc" ? "DESC" : "ASC"

    # SQL Server requires every ORDER BY column to appear in a DISTINCT select
    # list. The display columns are always projected; carry the order column
    # along only when it isn't one of them.
    if order_col && !display_cols.include?(order_col)
      qo          = conn.quote_column_name(order_col)
      select_list = (select_aliases + ["#{qo} AS sort_val"]).join(", ")
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
