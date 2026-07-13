# frozen_string_literal: true

[
  'BoxTimeTrackingSheets',
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
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/box_time_tracking_sheets.csv',
      local: 'box_time_tracking_sheets.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['unique_id',                   'unique_id',                   'nvarchar(max)', 'NULL', nil],
      ['box_number',                  'box_number',                  'nvarchar(max)', 'NULL', nil],
      ['pull_date',                   'pull_date',                   'nvarchar(max)', 'NULL', nil],
      ['pull_time',                   'pull_time',                   'nvarchar(max)', 'NULL', nil],
      ['total_prep_minutes',          'total_prep_minutes',          'nvarchar(max)', 'NULL', nil],
      ['total_scan_minutes',          'total_scan_minutes',          'nvarchar(max)', 'NULL', nil],
      ['wait_time_before_prep',       'wait_time_before_prep',       'nvarchar(max)', 'NULL', nil],
      ['wait_time_before_scan',       'wait_time_before_scan',       'nvarchar(max)', 'NULL', nil],
      ['wait_time_before_reshelving', 'wait_time_before_reshelving', 'nvarchar(max)', 'NULL', nil],
      ['total_overall_minutes',       'total_overall_minutes',       'nvarchar(max)', 'NULL', nil],
      ['reshelved_date',              'reshelved_date',              'nvarchar(max)', 'NULL', nil],
      ['reshelved_time',              'reshelved_time',              'nvarchar(max)', 'NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'box_time_tracking_sheets',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
