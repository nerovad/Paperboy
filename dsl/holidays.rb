# frozen_string_literal: true

[
  'Holidays',
  {
    steps: {
      enabled: true,
      manual_steps: Workflow::MANUAL_STEPS,
      scheduled: {
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'human_resources'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/holidays.csv',
      local: 'holidays.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['id', 'id', 'nvarchar(max)', 'NULL', nil],
      ['year', 'year', 'nvarchar(max)', 'NULL', nil],
      ['holiday', 'holiday', 'nvarchar(max)', 'NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'holidays',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
