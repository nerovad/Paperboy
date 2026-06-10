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

    cat_col   = cfg["category_column"].presence
    cat_col   = nil unless cat_col && columns.include?(cat_col)
    order_col = cfg["order_column"].presence
    order_col = nil unless order_col && columns.include?(order_col)

    qt = conn.quote_table_name(table)
    qc = conn.quote_column_name(col)

    where_sql = ""
    if cat_col && cfg["category_value"].present?
      where_sql = " WHERE #{conn.quote_column_name(cat_col)} = #{conn.quote(cfg["category_value"])}"
    end

    # Direction is a fixed keyword (never interpolated raw). Ascending/descending
    # is the only knob needed — numeric vs alphabetical follows the column type.
    dir = cfg["order_direction"].to_s.downcase == "desc" ? "DESC" : "ASC"

    sql =
      if order_col && order_col != col
        # SQL Server requires ORDER BY columns to appear in a DISTINCT select
        # list, so carry the order column along and project only the value.
        qo = conn.quote_column_name(order_col)
        "SELECT DISTINCT #{qc} AS val, #{qo} AS sort_val FROM #{qt}#{where_sql} ORDER BY #{qo} #{dir}"
      else
        "SELECT DISTINCT #{qc} AS val FROM #{qt}#{where_sql} ORDER BY #{qc} #{dir}"
      end

    conn.exec_query(sql).map { |row| row["val"] }.compact
  rescue => e
    Rails.logger.error("FormLookup.options(#{field_id}) failed: #{e.class}: #{e.message}")
    []
  end
end
