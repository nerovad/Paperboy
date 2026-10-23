# frozen_string_literal: true

module HumanResources
  # One page of a Human Resources grid. Identifiers come from GridCatalog,
  # never from the request, and are quoted before they reach GSABSS.
  class GridReader
    IDENTIFIER = /\A[A-Za-z_][A-Za-z0-9_]*\z/
    LIKE_LITERAL = { '%' => '[%]', '_' => '[_]', '[' => '[[]', ']' => '[]]' }.freeze

    def self.count(definition, query: nil, connection: GsabssBase.connection)
      sql = "SELECT COUNT(*) AS tally FROM #{qualified(definition, connection)}#{filter_sql(definition, query, connection)}"
      row = connection.exec_query(sql).first
      (row['tally'] || row.values.first).to_i
    end

    def self.rows(definition, offset:, limit:, query: nil, connection: GsabssBase.connection)
      list = column_list(definition, connection)
      sql = <<~SQL.squish
        SELECT #{list}
        FROM #{qualified(definition, connection)}#{filter_sql(definition, query, connection)}
        ORDER BY #{order_by(definition, connection)}
        OFFSET #{offset.to_i} ROWS FETCH NEXT #{limit.to_i} ROWS ONLY
      SQL
      connection.exec_query(sql).to_a.map { |row| values(row, definition.columns) }
    end

    def self.qualified(definition, connection)
      ensure_gsabss!(definition)
      return definition.from_clause.call(connection) if definition.from_clause

      "#{quote(definition.schema, connection)}.#{quote(definition.table, connection)}"
    end
    private_class_method :qualified

    def self.column_list(definition, connection)
      ensure_gsabss!(definition)
      return definition.select_list.call(connection) if definition.select_list

      definition.columns.map { |name| quote(name, connection) }.join(', ')
    end
    private_class_method :column_list

    def self.order_by(definition, connection)
      return definition.order_clause.call(connection) if definition.order_clause

      quote(definition.columns.first, connection)
    end
    private_class_method :order_by

    def self.search_targets(definition, connection)
      return definition.search_expressions.call(connection) if definition.search_expressions

      definition.search_columns.map { |name| quote(name, connection) }
    end
    private_class_method :search_targets

    # Chart of Accounts counts a match when every typed character appears in
    # order. A page holds 200 rows, so the same rule runs in SQL and the grid
    # stays ordered by its first column.
    def self.filter_sql(definition, query, connection)
      pattern = like_pattern(query)
      return '' if pattern.nil?

      quoted = connection.quote(pattern)
      clauses = search_targets(definition, connection).map do |expression|
        "LOWER(CAST(#{expression} AS nvarchar(4000))) LIKE #{quoted}"
      end
      raise ArgumentError, 'Human Resources grid has no search columns' if clauses.empty?

      " WHERE #{clauses.join(' OR ')}"
    end
    private_class_method :filter_sql

    def self.like_pattern(query)
      text = query.to_s.strip.downcase
      return if text.empty?

      "%#{text.chars.map { |char| LIKE_LITERAL.fetch(char, char) }.join('%')}%"
    end
    private_class_method :like_pattern

    def self.quote(name, connection)
      raise ArgumentError, 'Unsafe SQL identifier' unless IDENTIFIER.match?(name.to_s)

      connection.quote_column_name(name)
    end
    private_class_method :quote

    def self.ensure_gsabss!(definition)
      return if definition.database.casecmp('GSABSS').zero?

      raise ArgumentError, 'Human Resources grids read GSABSS'
    end
    private_class_method :ensure_gsabss!

    def self.values(row, columns)
      normalized = row.transform_keys { |key| key.to_s.downcase }
      columns.map { |name| normalized[name.downcase] }
    end
    private_class_method :values
  end
end
