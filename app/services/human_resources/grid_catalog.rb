# frozen_string_literal: true

module HumanResources
  # The sidebar grids. A single-table grid takes its names from the Data
  # Runner human_resources DSL. A replicated DSL is shown from its source
  # table; a file import is shown from the table it loads. GSA Employee is
  # the employees, units, and job salary join.
  class GridCatalog
    SIDEBAR = [
      { slug: 'employees', label: 'Employees', search: %w[id last_name first_name] },
      { slug: 'gsa_employees', label: 'GSA Employee', grid: GsaEmployees },
      { slug: 'bargaining_units', label: 'Bargaining Units', search: %w[bargaining_unit_id description] },
      { slug: 'flsa_statuses', label: 'FLSA Status', search: %w[flsa_stat_id description legend_rate_basis] },
      { slug: 'job_salaries', label: 'Job Salaries', search: %w[job_code_id job_title] },
      { slug: 'unions', label: 'Unions', search: %w[union_id description] },
      { slug: 'union_codes', label: 'Union codes', search: %w[union_id barg_unit vchrp_union description] },
      { slug: 'vchrp_unions', label: 'VCHRP unions', search: %w[vchrp_union_id description] }
    ].freeze

    Definition = Data.define(
      :slug, :label, :database, :schema, :table, :columns, :search_columns,
      :select_list, :from_clause, :order_clause, :search_expressions
    )

    def self.sidebar
      SIDEBAR.map { |item| find!(item[:slug]) }
    end

    def self.find!(slug)
      item = SIDEBAR.find { |entry| entry[:slug] == slug }
      raise ActiveRecord::RecordNotFound, 'Unknown Human Resources grid' unless item
      return item[:grid].definition if item[:grid]

      config = DslCatalog.find!(slug).config
      source = config[:source] || {}
      connection = Array(config[:database_connections]).first || {}
      from_source = source[:table].present?
      place = from_source ? source : connection
      columns = Array(config[:header]).filter_map { |row| row[from_source ? 0 : 1].presence }
      raise ActiveRecord::RecordNotFound, 'Human Resources grid has no table' if place[:table].blank? || columns.empty?

      search_columns = item[:search]
      missing = search_columns - columns
      raise ArgumentError, 'Human Resources search column is not on the grid' if missing.any?

      Definition.new(slug: slug, label: item[:label], database: place[:database].to_s,
                     schema: place[:schema].presence || 'dbo', table: place[:table], columns: columns,
                     search_columns: search_columns, select_list: nil, from_clause: nil,
                     order_clause: nil, search_expressions: nil)
    end
  end
end
