# frozen_string_literal: true

[
  'Paperboy_dev_solid_queue_blocked_executions',
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
    dependency: 'Paperboy_dev_solid_queue_jobs',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'solid_queue_blocked_executions',
      local: 'paperboy_dev_solid_queue_blocked_executions.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['job_id', 'job_id', 'bigint', 'NOT NULL', nil],
      ['queue_name', 'queue_name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['priority', 'priority', 'int', 'NOT NULL', nil],
      ['concurrency_key', 'concurrency_key', 'nvarchar(4000)', 'NOT NULL', nil],
      ['expires_at', 'expires_at', 'datetime2(6)', 'NOT NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'solid_queue_blocked_executions',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
