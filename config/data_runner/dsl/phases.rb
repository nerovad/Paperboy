# frozen_string_literal: true

[
  'Phases',
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
      url: 'http://acweb/cutoff/WP Phase on AUD Web Page.xlsx',
      location: 'phases.xlsx',
      local: 'phases.xlsx',
      format: :xlsx,
      strategy: :http
    },
    to_csv: {
      sheet: 0,
      header_row: 6,
      data_row: 7
    },
    header: [

      ['department',       'agency_id',  'nvarchar(3)',   'NOT NULL', nil],
      ['phase_code',       'phase_id',   'nvarchar(6)',   'NOT NULL', nil],
      ['phase_name',       'long_name',  'nvarchar(100)', 'NOT NULL', nil],
      ['phase_short_name', 'short_name', 'nvarchar(50)',  'NOT NULL', nil],
      ['active',           'active',     'bit',           'NOT NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'phases',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
