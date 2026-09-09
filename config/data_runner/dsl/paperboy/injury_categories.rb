# frozen_string_literal: true

[
  'InjuryCategories',
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
      name: 'paperboy'
    },
    source: {
      location: File.join(ENV.fetch('DATARUNNER_INBOX'), 'injury_classifications.xlsx'),
      local: 'injury_categories.xlsx',
      format: :xlsx,
      strategy: :copy
    },
    to_csv: {
      sheet: 1,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['id',          'id',          'bigint',        'IDENTITY(1,1) NOT NULL', nil],
      ['description', 'description', 'nvarchar(max)', 'NOT NULL',               nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'Paperboy_Dev',
        schema: 'dbo',
        table: 'injury_categories',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
