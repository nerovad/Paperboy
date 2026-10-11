# frozen_string_literal: true

[
  'Paperboy_dev_solid_queue_recurring_executions',
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
    dependency: 'Paperboy_dev_solid_queue_jobs',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'solid_queue_recurring_executions',
      local: 'paperboy_dev_solid_queue_recurring_executions.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['job_id', 'job_id', 'bigint', 'NOT NULL', nil],
      ['task_key', 'task_key', 'nvarchar(4000)', 'NOT NULL', nil],
      ['run_at', 'run_at', 'datetime2(6)', 'NOT NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'solid_queue_recurring_executions',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
