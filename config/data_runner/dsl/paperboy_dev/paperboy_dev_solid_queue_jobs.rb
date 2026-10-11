# frozen_string_literal: true

[
  'Paperboy_dev_solid_queue_jobs',
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
      table: 'solid_queue_jobs',
      local: 'paperboy_dev_solid_queue_jobs.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['queue_name', 'queue_name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['class_name', 'class_name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['arguments', 'arguments', 'nvarchar(max)', 'NULL', nil],
      ['priority', 'priority', 'int', 'NOT NULL', nil],
      ['active_job_id', 'active_job_id', 'nvarchar(4000)', 'NULL', nil],
      ['scheduled_at', 'scheduled_at', 'datetime2(6)', 'NULL', nil],
      ['finished_at', 'finished_at', 'datetime2(6)', 'NULL', nil],
      ['concurrency_key', 'concurrency_key', 'nvarchar(4000)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['batch_id', 'batch_id', 'bigint', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'solid_queue_jobs',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
