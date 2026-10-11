# frozen_string_literal: true

[
  'Gsabss_appropriations',
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
      name: 'gsabss'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSABSS',
      schema: 'dbo',
      table: 'appropriations',
      local: 'gsabss_appropriations.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['appropriation_unit', 'appropriation_unit', 'nvarchar(9)', 'NOT NULL', nil],
      ['appropriation_name', 'appropriation_name', 'nvarchar(100)', 'NOT NULL', nil],
      ['appropriation_short_name', 'appropriation_short_name', 'nvarchar(50)', 'NOT NULL', nil],
      ['appropriation_class', 'appropriation_class', 'nvarchar(4)', 'NOT NULL', nil],
      ['appropriation_category', 'appropriation_category', 'nvarchar(4)', 'NOT NULL', nil],
      ['active', 'active', 'bit', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'appropriations',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
