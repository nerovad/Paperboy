# frozen_string_literal: true

[
  'InjuryClassifications',
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
      name: 'paperboy'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/injury_classifications.xlsx',
      local: 'injury_classifications.xlsx',
      format: :xlsx,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      [ 'id',          'id',          'bigint',        'IDENTITY(1,1) NOT NULL', nil ],
      [ 'description', 'description', 'nvarchar(max)', 'NOT NULL',               nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'Paperboy_Dev',
        schema: 'dbo',
        table: 'injury_classifications',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
