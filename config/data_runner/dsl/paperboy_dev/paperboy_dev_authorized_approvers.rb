# frozen_string_literal: true

[
  'Paperboy_dev_authorized_approvers',
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
      table: 'authorized_approvers',
      local: 'paperboy_dev_authorized_approvers.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['employee_id', 'employee_id', 'nvarchar(4000)', 'NOT NULL', nil],
      ['department_id', 'department_id', 'nvarchar(4000)', 'NOT NULL', nil],
      ['service_type', 'service_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['key_type', 'key_type', 'nvarchar(4000)', 'NULL', nil],
      ['budget_units', 'budget_units', 'nvarchar(max)', 'NULL', nil],
      ['locations', 'locations', 'nvarchar(max)', 'NULL', nil],
      ['authorized_by', 'authorized_by', 'nvarchar(4000)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['all_budget_units', 'all_budget_units', 'bit', 'NOT NULL', nil],
      ['all_locations', 'all_locations', 'bit', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'authorized_approvers',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
