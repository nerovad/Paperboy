# frozen_string_literal: true

[
  'Groups',
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
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/00_Inbox/Groups.csv',
      local: 'Groups.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['groupid',     'groupid',     'int',           'IDENTITY(1,1) NOT NULL', nil],
      ['group_name',  'group_name',  'nvarchar(100)', 'NOT NULL',               nil],
      ['description', 'description', 'nvarchar(500)', 'NULL',                   nil],
      ['created_at',  'created_at',  'datetime',      'NULL',                   '(getdate())'],
    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'Paperboy_Dev',
        schema: 'dbo',
        table: 'Groups',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
