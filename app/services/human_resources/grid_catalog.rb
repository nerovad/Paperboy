# frozen_string_literal: true

module HumanResources
  # The seven sidebar grids. Table and column names come from the Data Runner
  # human_resources DSL. A replicated DSL is shown from its source table; a
  # file import is shown from the table it loads.
  class GridCatalog
    SIDEBAR = [
      { slug: 'employees', label: 'Employees' },
      { slug: 'bargaining_units', label: 'Bargaining Units' },
      { slug: 'flsa_statuses', label: 'FLSA Status' },
      { slug: 'job_salaries', label: 'Job Salaries' },
      { slug: 'unions', label: 'Unions' },
      { slug: 'union_codes', label: 'Union codes' },
      { slug: 'vchrp_unions', label: 'VCHRP unions' }
    ].freeze

    Definition = Data.define(:slug, :label, :database, :schema, :table, :columns)

    def self.sidebar
      SIDEBAR.map { |item| find!(item[:slug]) }
    end

    def self.find!(slug)
      item = SIDEBAR.find { |entry| entry[:slug] == slug }
      raise ActiveRecord::RecordNotFound, 'Unknown Human Resources grid' unless item

      config = DslCatalog.find!(slug).config
      source = config[:source] || {}
      connection = Array(config[:database_connections]).first || {}
      from_source = source[:table].present?
      place = from_source ? source : connection
      columns = Array(config[:header]).filter_map { |row| row[from_source ? 0 : 1].presence }
      raise ActiveRecord::RecordNotFound, 'Human Resources grid has no table' if place[:table].blank? || columns.empty?

      Definition.new(slug: slug, label: item[:label], database: place[:database].to_s,
                     schema: place[:schema].presence || 'dbo', table: place[:table], columns: columns)
    end
  end
end
