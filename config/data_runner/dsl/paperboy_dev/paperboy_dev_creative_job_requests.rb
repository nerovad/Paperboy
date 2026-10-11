# frozen_string_literal: true

[
  'Paperboy_dev_creative_job_requests',
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
      table: 'creative_job_requests',
      local: 'paperboy_dev_creative_job_requests.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['job_id', 'job_id', 'nvarchar(4000)', 'NULL', nil],
      ['job_title', 'job_title', 'nvarchar(4000)', 'NULL', nil],
      ['job_type', 'job_type', 'nvarchar(4000)', 'NULL', nil],
      ['job_agency', 'job_agency', 'nvarchar(4000)', 'NULL', nil],
      ['job_division', 'job_division', 'nvarchar(4000)', 'NULL', nil],
      ['job_department', 'job_department', 'nvarchar(4000)', 'NULL', nil],
      ['job_unit', 'job_unit', 'nvarchar(4000)', 'NULL', nil],
      ['asset_type', 'asset_type', 'nvarchar(4000)', 'NULL', nil],
      ['employee_name', 'employee_name', 'nvarchar(4000)', 'NULL', nil],
      ['location', 'location', 'nvarchar(4000)', 'NULL', nil],
      ['date', 'date', 'date', 'NULL', nil],
      ['description', 'description', 'nvarchar(max)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'creative_job_requests',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
