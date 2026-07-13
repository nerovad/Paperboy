# frozen_string_literal: true

[
  'BoxRawTimeData',
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
      name: 'scan_center'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/box_raw_time_data.csv',
      local: 'box_raw_time_data.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['unique_id',         'unique_id',         'nvarchar(max)', 'NULL', nil],
      ['box_number',        'box_number',        'nvarchar(max)', 'NULL', nil],
      ['event_type',        'event_type',        'nvarchar(max)', 'NULL', nil],
      ['date',              'date',              'nvarchar(max)', 'NULL', nil],
      ['start_time',        'start_time',        'nvarchar(max)', 'NULL', nil],
      ['end_time',          'end_time',          'nvarchar(max)', 'NULL', nil],
      ['handwritten_notes', 'handwritten_notes', 'nvarchar(max)', 'NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'box_raw_time_data',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
