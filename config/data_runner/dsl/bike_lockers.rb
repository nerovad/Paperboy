# frozen_string_literal: true

[
  'Bike_lockers',
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
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/00_Inbox/bike_lockers.csv',
      local: 'bike_lockers.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['id',                   'id',                   'bigint',         'IDENTITY(0,0) NOT NULL', nil],
      ['lot_id',               'lot_id',               'bigint',         'NOT NULL',               nil],
      ['locker_number',        'locker_number',        'int',            'NOT NULL',               nil],
      ['status',               'status',               'nvarchar(4000)', 'NOT NULL',               '(N\'available\')'],
      ['assigned_employee_id', 'assigned_employee_id', 'nvarchar(4000)', 'NULL',                   nil],
      ['assigned_at',          'assigned_at',          'datetime2(6)',   'NULL',                   nil],
      ['created_at',           'created_at',           'datetime2(6)',   'NOT NULL',               nil],
      ['updated_at',           'updated_at',           'datetime2(6)',   'NOT NULL',               nil]
    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'Paperboy_Dev',
        schema: 'dbo',
        table: 'bike_lockers',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
