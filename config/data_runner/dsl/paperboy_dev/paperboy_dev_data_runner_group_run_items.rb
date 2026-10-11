# frozen_string_literal: true

[
  'Paperboy_dev_data_runner_group_run_items',
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
    dependency: 'Paperboy_dev_data_runner_group_runs',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'data_runner_group_run_items',
      local: 'paperboy_dev_data_runner_group_run_items.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['group_run_id', 'group_run_id', 'bigint', 'NOT NULL', nil],
      ['dsl_name', 'dsl_name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['dsl_slug', 'dsl_slug', 'nvarchar(4000)', 'NOT NULL', nil],
      ['status', 'status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['position', 'position', 'int', 'NOT NULL', nil],
      ['error_message', 'error_message', 'nvarchar(max)', 'NULL', nil],
      ['started_at', 'started_at', 'datetime2(6)', 'NULL', nil],
      ['completed_at', 'completed_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['duration_ms', 'duration_ms', 'int', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'data_runner_group_run_items',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
