# frozen_string_literal: true

[
  'Paperboy_dev_sql_dashboard_events',
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
      table: 'sql_dashboard_events',
      local: 'paperboy_dev_sql_dashboard_events.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['sql_dashboard_query_id', 'sql_dashboard_query_id', 'bigint', 'NULL', nil],
      ['query_name', 'query_name', 'nvarchar(4000)', 'NULL', nil],
      ['action', 'action', 'nvarchar(4000)', 'NOT NULL', nil],
      ['employee_id', 'employee_id', 'nvarchar(4000)', 'NULL', nil],
      ['employee_name', 'employee_name', 'nvarchar(4000)', 'NULL', nil],
      ['database_key', 'database_key', 'nvarchar(4000)', 'NULL', nil],
      ['statement', 'statement', 'nvarchar(max)', 'NULL', nil],
      ['duration_ms', 'duration_ms', 'int', 'NULL', nil],
      ['row_count', 'row_count', 'int', 'NULL', nil],
      ['error_message', 'error_message', 'nvarchar(max)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'sql_dashboard_events',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
