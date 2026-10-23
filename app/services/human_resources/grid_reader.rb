# frozen_string_literal: true

module HumanResources
  # One page of a Human Resources grid. Identifiers come from GridCatalog,
  # never from the request, and are quoted before they reach GSABSS.
  class GridReader
    IDENTIFIER = /\A[A-Za-z_][A-Za-z0-9_]*\z/

    def self.count(definition, connection: GsabssBase.connection)
      row = connection.exec_query("SELECT COUNT(*) AS tally FROM #{qualified(definition, connection)}").first
      (row['tally'] || row.values.first).to_i
    end

    def self.rows(definition, offset:, limit:, connection: GsabssBase.connection)
      list = column_list(definition, connection)
      sql = <<~SQL.squish
        SELECT #{list}
        FROM #{qualified(definition, connection)}
        ORDER BY #{quote(definition.columns.first, connection)}
        OFFSET #{offset.to_i} ROWS FETCH NEXT #{limit.to_i} ROWS ONLY
      SQL
      connection.exec_query(sql).to_a.map { |row| values(row, definition.columns) }
    end

    def self.qualified(definition, connection)
      ensure_gsabss!(definition)
      "#{quote(definition.schema, connection)}.#{quote(definition.table, connection)}"
    end
    private_class_method :qualified

    def self.column_list(definition, connection)
      ensure_gsabss!(definition)
      definition.columns.map { |name| quote(name, connection) }.join(', ')
    end
    private_class_method :column_list

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
