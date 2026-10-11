# frozen_string_literal: true

[
  'Paperboy_dev_authorization_fos',
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
      table: 'authorization_fos',
      local: 'paperboy_dev_authorization_fos.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['employee_id', 'employee_id', 'nvarchar(4000)', 'NULL', nil],
      ['name', 'name', 'nvarchar(4000)', 'NULL', nil],
      ['phone', 'phone', 'nvarchar(4000)', 'NULL', nil],
      ['email', 'email', 'nvarchar(4000)', 'NULL', nil],
      ['agency', 'agency', 'nvarchar(4000)', 'NULL', nil],
      ['division', 'division', 'nvarchar(4000)', 'NULL', nil],
      ['department', 'department', 'nvarchar(4000)', 'NULL', nil],
      ['unit', 'unit', 'nvarchar(4000)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'authorization_fos',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
