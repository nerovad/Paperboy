# frozen_string_literal: true

[
  'Employee_Groups',
  {
    steps: {
      enabled: true,
      manual_steps: Workflow::MANUAL_STEPS,
      scheduled: {
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/00_Inbox/Employee_Groups.csv',
      local: 'Employee_Groups.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['id',          'id',          'bigint',   'IDENTITY(0,0) NOT NULL', nil],
      ['employeeid',  'employeeid',  'int',      'NOT NULL',               nil],
      ['groupid',     'groupid',     'bigint',   'NOT NULL',               nil],
      ['assigned_at', 'assigned_at', 'datetime', 'NULL',                   '(getdate())'],
      ['assigned_by', 'assigned_by', 'int',      'NULL',                   nil],
    ],
    database_connections: [
      {
        host: 'gsasql16',
        database: 'Paperboy_Dev',
        schema: 'dbo',
        table: 'Employee_Groups',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
