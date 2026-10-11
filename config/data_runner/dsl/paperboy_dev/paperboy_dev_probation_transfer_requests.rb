# frozen_string_literal: true

[
  'Paperboy_dev_probation_transfer_requests',
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
      table: 'probation_transfer_requests',
      local: 'paperboy_dev_probation_transfer_requests.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['employee_id', 'employee_id', 'nvarchar(20)', 'NULL', nil],
      ['name', 'name', 'nvarchar(200)', 'NULL', nil],
      ['email', 'email', 'nvarchar(200)', 'NULL', nil],
      ['phone', 'phone', 'nvarchar(25)', 'NULL', nil],
      ['agency', 'agency', 'nvarchar(100)', 'NULL', nil],
      ['division', 'division', 'nvarchar(100)', 'NULL', nil],
      ['department', 'department', 'nvarchar(100)', 'NULL', nil],
      ['unit', 'unit', 'nvarchar(100)', 'NULL', nil],
      ['work_location', 'work_location', 'nvarchar(100)', 'NULL', nil],
      ['current_assignment_date', 'current_assignment_date', 'date', 'NULL', nil],
      ['desired_transfer_destination', 'desired_transfer_destination', 'nvarchar(max)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['other_transfer_destination', 'other_transfer_destination', 'nvarchar(200)', 'NULL', nil],
      ['approved_by', 'approved_by', 'nvarchar(20)', 'NULL', nil],
      ['approved_at', 'approved_at', 'datetime2(6)', 'NULL', nil],
      ['denied_by', 'denied_by', 'nvarchar(20)', 'NULL', nil],
      ['denied_at', 'denied_at', 'datetime2(6)', 'NULL', nil],
      ['denial_reason', 'denial_reason', 'nvarchar(max)', 'NULL', nil],
      ['supervisor_email', 'supervisor_email', 'nvarchar(200)', 'NULL', nil],
      ['supervisor_id', 'supervisor_id', 'nvarchar(20)', 'NULL', nil],
      ['expires_at', 'expires_at', 'datetime2(6)', 'NULL', nil],
      ['canceled_at', 'canceled_at', 'datetime2(6)', 'NULL', nil],
      ['canceled_reason', 'canceled_reason', 'nvarchar(100)', 'NULL', nil],
      ['superseded_by_id', 'superseded_by_id', 'bigint', 'NULL', nil],
      ['approved_destination', 'approved_destination', 'nvarchar(4000)', 'NULL', nil],
      ['status', 'status', 'nvarchar(4000)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'probation_transfer_requests',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
