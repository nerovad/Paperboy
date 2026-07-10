# frozen_string_literal: true

[
  'Workweeks',
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
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/workweeks.csv',
      local: 'workweeks.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      [ 'id', 'id', 'nvarchar(max)', 'NULL', nil ],
      [ 'year', 'year', 'nvarchar(max)', 'NULL', nil ],
      [ 'work_week', 'work_week', 'nvarchar(max)', 'NULL', nil ],
      [ 'start_date', 'start_date', 'nvarchar(max)', 'NULL', nil ],
      [ 'end_date', 'end_date', 'nvarchar(max)', 'NULL', nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'workweeks',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
