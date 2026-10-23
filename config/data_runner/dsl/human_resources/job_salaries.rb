# frozen_string_literal: true

[
  'JobSalaries',
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
      location: File.join(ENV.fetch('DATARUNNER_INBOX'), 'job_salaries.csv'),
      local: 'job_salaries.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['job_code_id',    'job_code_id',    'nvarchar(max)', 'NULL', nil],
      ['job_title',      'job_title',      'nvarchar(max)', 'NULL', nil],
      ['at_will',        'at_will',        'nvarchar(max)', 'NULL', nil],
      ['vchrp_code',     'vchrp_code',     'nvarchar(max)', 'NULL', nil],
      ['flsa_stat',      'flsa_stat',      'nvarchar(max)', 'NULL', nil],
      ['rate_basis',     'rate_basis',     'nvarchar(max)', 'NULL', nil],
      ['rate_min',       'rate_min',       'nvarchar(max)', 'NULL', nil],
      ['rate_max',       'rate_max',       'nvarchar(max)', 'NULL', nil],
      ['hours_per_year', 'hours_per_year', 'nvarchar(max)', 'NULL', nil],
      ['pays_per_year',  'pays_per_year',  'nvarchar(max)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'GSASQL16.ent.co.ventura.ca.us',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'job_salaries',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
