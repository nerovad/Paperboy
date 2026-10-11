# frozen_string_literal: true

[
  'Paperboy_dev_employee_groups',
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
      table: 'Employee_Groups',
      local: 'paperboy_dev_employee_groups.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['EmployeeID', 'EmployeeID', 'int', 'NOT NULL', nil],
      ['GroupID', 'GroupID', 'bigint', 'NOT NULL', nil],
      ['Assigned_At', 'Assigned_At', 'datetime', 'NULL', nil],
      ['Assigned_By', 'Assigned_By', 'int', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'Employee_Groups',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
