# frozen_string_literal: true

[
  'ParkingLots',
  {
    steps: {
      enabled: false,
      manual_steps: Workflow::MANUAL_STEPS,
      scheduled: {
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'paperboy'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/parking_lots.csv',
      local: 'parking_lots.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      [ 'id',   'id',   'nvarchar(max)', 'NULL', nil ],
      [ 'name', 'name', 'nvarchar(max)', 'NULL', nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'parking_lots',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
