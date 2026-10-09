# frozen_string_literal: true

[
  'Paperboy_dev_task_reassignments',
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
      table: 'task_reassignments',
      local: 'paperboy_dev_task_reassignments.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['task_type', 'task_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['task_id', 'task_id', 'bigint', 'NOT NULL', nil],
      ['from_employee_id', 'from_employee_id', 'nvarchar(4000)', 'NOT NULL', nil],
      ['to_employee_id', 'to_employee_id', 'nvarchar(4000)', 'NOT NULL', nil],
      ['reassigned_by_id', 'reassigned_by_id', 'nvarchar(4000)', 'NOT NULL', nil],
      ['reason', 'reason', 'nvarchar(max)', 'NULL', nil],
      ['assignment_field', 'assignment_field', 'nvarchar(4000)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'task_reassignments',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
