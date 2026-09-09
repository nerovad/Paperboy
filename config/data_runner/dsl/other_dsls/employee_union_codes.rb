# frozen_string_literal: true

[
  'Employee_union_codes',
  {
    steps: {
      manual: { enabled: true, steps: Workflow::MANUAL_STEPS },
      scheduled: { enabled: true, frequency: :daily, steps: Workflow::SCHEDULED_STEPS }
    },
    source: {
      host: 'GSASQL16',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'employee_union_codes',
      local: 'employee_union_codes.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id',          'id',          'bigint',         'IDENTITY(1,1) NOT NULL', nil],
      ['employee_id', 'employee_id', 'nvarchar(4000)', 'NOT NULL',               nil],
      ['union_code',  'union_code',  'nvarchar(4000)', 'NOT NULL',               nil],
      ['created_at',  'created_at',  'datetime2(6)',   'NOT NULL',               nil],
      ['updated_at',  'updated_at',  'datetime2(6)',   'NOT NULL',               nil]
    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'employee_union_codes',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
