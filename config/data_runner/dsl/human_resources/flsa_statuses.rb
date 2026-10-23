# frozen_string_literal: true

[
  'FlsaStatuses',
  {
    steps: {
      manual: {
        enabled: true,
        steps: Workflow::MANUAL_STEPS
      },
      scheduled: {
        enabled: true,
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'human_resources'
    },
    source: {
      location: File.join(ENV.fetch('DATARUNNER_INBOX'), 'flsa_statuses.csv'),
      local: 'flsa_statuses.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['flsa_stat_id',      'flsa_stat_id',      'nvarchar(max)', 'NULL', nil],
      ['description',       'description',       'nvarchar(max)', 'NULL', nil],
      ['legend_rate_basis', 'legend_rate_basis', 'nvarchar(max)', 'NULL', nil],
    ],
    database_connections: [
      {
        host: 'GSASQL16.ent.co.ventura.ca.us',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'flsa_statuses',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
