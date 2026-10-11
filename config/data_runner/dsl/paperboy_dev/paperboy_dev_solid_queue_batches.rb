# frozen_string_literal: true

[
  'Paperboy_dev_solid_queue_batches',
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
      table: 'solid_queue_batches',
      local: 'paperboy_dev_solid_queue_batches.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['active_job_batch_id', 'active_job_batch_id', 'nvarchar(4000)', 'NULL', nil],
      ['description', 'description', 'nvarchar(4000)', 'NULL', nil],
      ['on_finish', 'on_finish', 'nvarchar(max)', 'NULL', nil],
      ['on_success', 'on_success', 'nvarchar(max)', 'NULL', nil],
      ['on_failure', 'on_failure', 'nvarchar(max)', 'NULL', nil],
      ['metadata', 'metadata', 'nvarchar(max)', 'NULL', nil],
      ['total_jobs', 'total_jobs', 'int', 'NOT NULL', nil],
      ['completed_jobs', 'completed_jobs', 'int', 'NOT NULL', nil],
      ['failed_jobs', 'failed_jobs', 'int', 'NOT NULL', nil],
      ['enqueued_at', 'enqueued_at', 'datetime2(6)', 'NULL', nil],
      ['finished_at', 'finished_at', 'datetime2(6)', 'NULL', nil],
      ['failed_at', 'failed_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'solid_queue_batches',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
