# frozen_string_literal: true

[
  'Paperboy_dev_parking_lot_submissions',
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
      table: 'parking_lot_submissions',
      local: 'paperboy_dev_parking_lot_submissions.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['name', 'name', 'nvarchar(200)', 'NULL', nil],
      ['phone', 'phone', 'nvarchar(25)', 'NULL', nil],
      ['employee_id', 'employee_id', 'nvarchar(20)', 'NULL', nil],
      ['email', 'email', 'nvarchar(200)', 'NULL', nil],
      ['agency', 'agency', 'nvarchar(100)', 'NULL', nil],
      ['division', 'division', 'nvarchar(100)', 'NULL', nil],
      ['department', 'department', 'nvarchar(100)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['unit', 'unit', 'nvarchar(100)', 'NULL', nil],
      ['supervisor_id', 'supervisor_id', 'nvarchar(20)', 'NULL', nil],
      ['approved_by', 'approved_by', 'nvarchar(20)', 'NULL', nil],
      ['approved_at', 'approved_at', 'datetime2(6)', 'NULL', nil],
      ['denied_by', 'denied_by', 'nvarchar(20)', 'NULL', nil],
      ['denied_at', 'denied_at', 'datetime2(6)', 'NULL', nil],
      ['denial_reason', 'denial_reason', 'nvarchar(max)', 'NULL', nil],
      ['supervisor_email', 'supervisor_email', 'nvarchar(200)', 'NULL', nil],
      ['status', 'status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['approver_id', 'approver_id', 'nvarchar(4000)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'parking_lot_submissions',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
