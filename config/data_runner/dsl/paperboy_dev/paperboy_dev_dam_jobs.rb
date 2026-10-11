# frozen_string_literal: true

[
  'Paperboy_dev_dam_jobs',
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
    dependency: 'Paperboy_dev_dam_workflows',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'dam_jobs',
      local: 'paperboy_dev_dam_jobs.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['job_type', 'job_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['workflow_id', 'workflow_id', 'bigint', 'NULL', nil],
      ['subject_type', 'subject_type', 'nvarchar(4000)', 'NULL', nil],
      ['subject_id', 'subject_id', 'bigint', 'NULL', nil],
      ['subject_label', 'subject_label', 'nvarchar(4000)', 'NULL', nil],
      ['status', 'status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['total_items', 'total_items', 'int', 'NOT NULL', nil],
      ['processed_items', 'processed_items', 'int', 'NOT NULL', nil],
      ['queued_at', 'queued_at', 'datetime2(6)', 'NULL', nil],
      ['started_at', 'started_at', 'datetime2(6)', 'NULL', nil],
      ['finished_at', 'finished_at', 'datetime2(6)', 'NULL', nil],
      ['error_message', 'error_message', 'nvarchar(max)', 'NULL', nil],
      ['log', 'log', 'nvarchar(max)', 'NULL', nil],
      ['created_by_id', 'created_by_id', 'nvarchar(4000)', 'NULL', nil],
      ['created_by_name', 'created_by_name', 'nvarchar(4000)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'dam_jobs',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
