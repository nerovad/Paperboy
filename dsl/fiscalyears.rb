# frozen_string_literal: true

[
  'Fiscalyears',
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
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/fiscalyears.csv',
      local: 'fiscalyears.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      [ 'year',  'year',  'nvarchar(4)', 'NOT NULL', nil ],
      [ 'sdate', 'sdate', 'date',        'NOT NULL', nil ],
      [ 'edate', 'edate', 'date',        'NOT NULL', nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'fiscalyears',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
