# frozen_string_literal: true

[
  'Paperboy_dev_authorized_approver_changes',
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
      table: 'authorized_approver_changes',
      local: 'paperboy_dev_authorized_approver_changes.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['action', 'action', 'nvarchar(4000)', 'NOT NULL', nil],
      ['employee_id', 'employee_id', 'nvarchar(4000)', 'NOT NULL', nil],
      ['department_id', 'department_id', 'nvarchar(4000)', 'NOT NULL', nil],
      ['changed_by', 'changed_by', 'nvarchar(4000)', 'NOT NULL', nil],
      ['scope_before', 'scope_before', 'nvarchar(max)', 'NULL', nil],
      ['scope_after', 'scope_after', 'nvarchar(max)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'authorized_approver_changes',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
