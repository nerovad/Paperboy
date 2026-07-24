# frozen_string_literal: true

[
  'MajorPrograms',
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
      name: 'chart_of_accounts'
    },
    source: {
      url: 'http://acweb/cutoff/WP Major Program on AUD Web Page.xlsx',
      location: 'major_programs.xlsx',
      local: 'major_programs.xlsx',
      format: :xlsx,
      strategy: :http
    },
    to_csv: {
      sheet: 0,
      header_row: 6,
      data_row: 7
    },
    header: [

      ['department',         'agency_id',        'nvarchar(3)',   'NOT NULL', nil],
      ['major_program_code', 'major_program_id', 'nvarchar(10)',  'NOT NULL', nil],
      ['long_name',          'long_name',        'nvarchar(100)', 'NOT NULL', nil],
      ['short_name',         'short_name',       'nvarchar(50)',  'NOT NULL', nil],
      ['active',             'active',           'bit',           'NOT NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'major_programs',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
