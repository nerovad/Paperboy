# frozen_string_literal: true

[
  'Paperboy_dev_contractors',
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
      table: 'contractors',
      local: 'paperboy_dev_contractors.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['first_name', 'first_name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['last_name', 'last_name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['email', 'email', 'nvarchar(4000)', 'NOT NULL', nil],
      ['work_phone', 'work_phone', 'nvarchar(4000)', 'NULL', nil],
      ['agency', 'agency', 'nvarchar(4000)', 'NULL', nil],
      ['department', 'department', 'nvarchar(4000)', 'NULL', nil],
      ['unit', 'unit', 'nvarchar(4000)', 'NULL', nil],
      ['supervisor_id', 'supervisor_id', 'int', 'NULL', nil],
      ['password_digest', 'password_digest', 'nvarchar(4000)', 'NULL', nil],
      ['active', 'active', 'bit', 'NOT NULL', nil],
      ['expires_at', 'expires_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'contractors',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
