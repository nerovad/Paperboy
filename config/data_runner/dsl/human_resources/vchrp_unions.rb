# frozen_string_literal: true

[
  'VchrpUnions',
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
      location: File.join(ENV.fetch('DATARUNNER_INBOX'), 'vchrp_unions.csv'),
      local: 'vchrp_unions.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['vchrp_union_id', 'vchrp_union_id', 'nvarchar(max)', 'NULL', nil],
      ['description',    'description',    'nvarchar(max)', 'NULL', nil],
    ],
    database_connections: [
      {
        host: 'GSASQL16.ent.co.ventura.ca.us',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'vchrp_unions',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
