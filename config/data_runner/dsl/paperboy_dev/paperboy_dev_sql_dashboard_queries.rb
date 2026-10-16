# frozen_string_literal: true

[
  'Paperboy_dev_sql_dashboard_queries',
  {
    steps: {
      manual: {
        enabled: true,
        steps: Workflow::REPLICATE_STEPS
      },
      scheduled: {
        enabled: false,
        frequency: :daily,
        steps: Workflow::REPLICATE_STEPS
      }
    },
    group: {
      name: 'paperboy_dev'
    },
    source: {
      host: 'GSASQL16',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'sql_dashboard_queries',
      local: 'paperboy_dev_sql_dashboard_queries.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['name', 'name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['description', 'description', 'nvarchar(max)', 'NULL', nil],
      ['database_key', 'database_key', 'nvarchar(4000)', 'NOT NULL', nil],
      ['chart_type', 'chart_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['statement', 'statement', 'nvarchar(max)', 'NOT NULL', nil],
      ['created_by_id', 'created_by_id', 'nvarchar(4000)', 'NULL', nil],
      ['created_by_name', 'created_by_name', 'nvarchar(4000)', 'NULL', nil],
      ['updated_by_id', 'updated_by_id', 'nvarchar(4000)', 'NULL', nil],
      ['updated_by_name', 'updated_by_name', 'nvarchar(4000)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'sql_dashboard_queries',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
