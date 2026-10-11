# frozen_string_literal: true

[
  'Paperboy_dev_notice_of_change_forms',
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
      table: 'notice_of_change_forms',
      local: 'paperboy_dev_notice_of_change_forms.csv',
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
      ['approver_id', 'approver_id', 'nvarchar(4000)', 'NULL', nil],
      ['deny_reason', 'deny_reason', 'nvarchar(max)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['status', 'status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['change_or_service_requested', 'change_or_service_requested', 'nvarchar(4000)', 'NULL', nil],
      ['old_location_or_address', 'old_location_or_address', 'nvarchar(4000)', 'NULL', nil],
      ['new_location_or_address', 'new_location_or_address', 'nvarchar(4000)', 'NULL', nil],
      ['description_of_new_service', 'description_of_new_service', 'nvarchar(max)', 'NULL', nil],
      ['object', 'object', 'nvarchar(4000)', 'NULL', nil],
      ['activity', 'activity', 'nvarchar(4000)', 'NULL', nil],
      ['function', 'function', 'nvarchar(4000)', 'NULL', nil],
      ['program', 'program', 'nvarchar(4000)', 'NULL', nil],
      ['phase', 'phase', 'nvarchar(4000)', 'NULL', nil],
      ['task', 'task', 'nvarchar(4000)', 'NULL', nil],
      ['monthly_cost', 'monthly_cost', 'nvarchar(4000)', 'NULL', nil],
      ['annual_cost', 'annual_cost', 'nvarchar(4000)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'notice_of_change_forms',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
