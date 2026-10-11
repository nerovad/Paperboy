# frozen_string_literal: true

[
  'Paperboy_dev_development_runs',
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
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'development_runs',
      local: 'paperboy_dev_development_runs.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['script_key', 'script_key', 'nvarchar(4000)', 'NOT NULL', nil],
      ['script_label', 'script_label', 'nvarchar(4000)', 'NOT NULL', nil],
      ['command_json', 'command_json', 'nvarchar(max)', 'NOT NULL', nil],
      ['requested_by', 'requested_by', 'nvarchar(4000)', 'NOT NULL', nil],
      ['status', 'status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['output', 'output', 'nvarchar(max)', 'NULL', nil],
      ['exit_status', 'exit_status', 'int', 'NULL', nil],
      ['started_at', 'started_at', 'datetime2(6)', 'NULL', nil],
      ['finished_at', 'finished_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'development_runs',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
