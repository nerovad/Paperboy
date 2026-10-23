# frozen_string_literal: true

module HumanResources
  # GSA staff. employees.unit matches units.unit_id, the unit is GSA, and
  # employees.job_code matches job_salaries.job_code_id. The employee id
  # column on the source table is id.
  class GsaEmployees
    COLUMNS = [
      %w[units agency_id agency_id],
      %w[units division_id division_id],
      %w[units department_id department_id],
      %w[units unit_id unit_id],
      %w[employees id employee_id],
      %w[employees first_name first_name],
      %w[employees last_name last_name],
      %w[employees job_code job_code],
      %w[job_salaries job_title job_title],
      %w[job_salaries at_will at_will],
      %w[job_salaries vchrp_code vchrp_code],
      %w[job_salaries flsa_stat flsa_stat],
      %w[job_salaries rate_basis rate_basis],
      %w[job_salaries rate_min rate_min],
      %w[job_salaries rate_max rate_max]
    ].freeze

    SEARCH = [
      %w[units agency_id],
      %w[units division_id],
      %w[units department_id],
      %w[units unit_id],
      %w[job_salaries job_code_id],
      %w[job_salaries job_title],
      %w[employees id],
      %w[employees first_name],
      %w[employees last_name]
    ].freeze

    def self.definition
      GridCatalog::Definition.new(
        slug: 'gsa_employees', label: 'GSA Employee', database: 'GSABSS', schema: 'dbo',
        table: 'gsa_employees', columns: COLUMNS.map(&:last),
        search_columns: %w[agency_id division_id department_id unit_id job_code_id job_title
                           employee_id first_name last_name],
        select_list: method(:select_list), from_clause: method(:from_clause),
        order_clause: method(:order_clause), search_expressions: method(:search_expressions)
      )
    end

    def self.select_list(connection)
      COLUMNS.map do |table, column, label|
        "#{ref(connection, table, column)} AS #{column_name(connection, label)}"
      end.join(', ')
    end

    def self.search_expressions(connection)
      SEARCH.map { |table, column| ref(connection, table, column) }
    end

    def self.order_clause(connection)
      ref(connection, 'employees', 'id')
    end

    def self.from_clause(connection)
      employees = column_name(connection, 'employees')
      units = column_name(connection, 'units')
      salaries = column_name(connection, 'job_salaries')
      <<~SQL.squish
        #{employees}
        INNER JOIN #{units}
          ON #{employees}.#{column_name(connection, 'unit')} = #{units}.#{column_name(connection, 'unit_id')}
         AND #{units}.#{column_name(connection, 'agency_id')} = #{connection.quote('GSA')}
        INNER JOIN #{salaries}
          ON #{employees}.#{column_name(connection, 'job_code')} =
             #{salaries}.#{column_name(connection, 'job_code_id')}
      SQL
    end

    def self.ref(connection, table, column)
      "#{column_name(connection, table)}.#{column_name(connection, column)}"
    end
    private_class_method :ref

    def self.column_name(connection, name)
      raise ArgumentError, 'Unsafe SQL identifier' unless GridReader::IDENTIFIER.match?(name)

      connection.quote_column_name(name)
    end
    private_class_method :column_name
  end
end
