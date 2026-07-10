# frozen_string_literal: true

[
  'Boxes',
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
      name: 'scan_center'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/boxes.csv',
      local: 'boxes.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      [ 'box_barcode',              'box_barcode',              'nvarchar(6)',   'NOT NULL', nil ],
      [ 'first_activity_timestamp', 'first_activity_timestamp', 'datetime2(7)',  'NULL',     nil ],
      [ 'last_activity_timestamp',  'last_activity_timestamp',  'datetime2(7)',  'NULL',     nil ],
      [ 'notes',                    'notes',                    'nvarchar(max)', 'NULL',     nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSA_HR',
        schema: 'dbo',
        table: 'boxes',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
