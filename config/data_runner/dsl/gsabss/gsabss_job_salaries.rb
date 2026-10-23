# frozen_string_literal: true

[
  'Gsabss_job_salaries',
  {
    steps: {
      manual: {
        enabled: true,
        steps: Workflow::REPLICATE_STEPS
      },
      scheduled: {
        enabled: false,
        frequency: :daily,
        steps: Workflow::REPLICATE_STEPS
      }
    },
    group: {
      name: 'gsabss'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSABSS',
      schema: 'dbo',
      table: 'job_salaries',
      local: 'gsabss_job_salaries.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['job_code_id', 'job_code_id', 'nvarchar(max)', 'NULL', nil],
      ['job_title', 'job_title', 'nvarchar(max)', 'NULL', nil],
      ['at_will', 'at_will', 'nvarchar(max)', 'NULL', nil],
      ['vchrp_code', 'vchrp_code', 'nvarchar(max)', 'NULL', nil],
      ['flsa_stat', 'flsa_stat', 'nvarchar(max)', 'NULL', nil],
      ['rate_basis', 'rate_basis', 'nvarchar(max)', 'NULL', nil],
      ['rate_min', 'rate_min', 'nvarchar(max)', 'NULL', nil],
      ['rate_max', 'rate_max', 'nvarchar(max)', 'NULL', nil],
      ['hours_per_year', 'hours_per_year', 'nvarchar(max)', 'NULL', nil],
      ['pays_per_year', 'pays_per_year', 'nvarchar(max)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'job_salaries',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
