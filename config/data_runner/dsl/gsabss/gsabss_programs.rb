# frozen_string_literal: true

[
  'Gsabss_programs',
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
      table: 'programs',
      local: 'gsabss_programs.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['agency_id', 'agency_id', 'nvarchar(3)', 'NOT NULL', nil],
      ['program_id', 'program_id', 'nvarchar(10)', 'NOT NULL', nil],
      ['major_program_id', 'major_program_id', 'nvarchar(10)', 'NOT NULL', nil],
      ['long_name', 'long_name', 'nvarchar(100)', 'NOT NULL', nil],
      ['short_name', 'short_name', 'nvarchar(50)', 'NOT NULL', nil],
      ['active', 'active', 'bit', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'programs',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
