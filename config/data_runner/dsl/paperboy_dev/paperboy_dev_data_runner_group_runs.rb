# frozen_string_literal: true

[
  'Paperboy_dev_data_runner_group_runs',
  {
     steps: {
      manual: {
        enabled: true,
        steps: Workflow::MANUAL_STEPS
      },
      scheduled: {
        enabled: true,
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'paperboy_dev'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'data_runner_group_runs',
      local: 'paperboy_dev_data_runner_group_runs.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['run_id', 'run_id', 'nvarchar(4000)', 'NOT NULL', nil],
      ['group_name', 'group_name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['status', 'status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['total_count', 'total_count', 'int', 'NOT NULL', nil],
      ['completed_count', 'completed_count', 'int', 'NOT NULL', nil],
      ['failed_count', 'failed_count', 'int', 'NOT NULL', nil],
      ['current_dsl', 'current_dsl', 'nvarchar(4000)', 'NULL', nil],
      ['requested_by', 'requested_by', 'nvarchar(4000)', 'NULL', nil],
      ['started_at', 'started_at', 'datetime2(6)', 'NULL', nil],
      ['completed_at', 'completed_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'data_runner_group_runs',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
