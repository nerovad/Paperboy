# frozen_string_literal: true

[
  'Gsap2m_jobcost',
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
      name: 'gsap2m'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSAP2M',
      schema: 'dbo',
      table: '_JobCost',
      local: 'gsap2m_jobcost.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['AGENCY', 'AGENCY', 'nvarchar(100)', 'NOT NULL', nil],
      ['CUNIT', 'CUNIT', 'nvarchar(100)', 'NOT NULL', nil],
      ['POSTING_REF', 'POSTING_REF', 'nvarchar(100)', 'NOT NULL', nil],
      ['DESCRIPTION', 'DESCRIPTION', 'nvarchar(100)', 'NOT NULL', nil],
      ['JOBID', 'JOBID', 'nvarchar(100)', 'NOT NULL', nil],
      ['OMS_NUMBER', 'OMS_NUMBER', 'nvarchar(100)', 'NOT NULL', nil],
      ['SERVICE', 'SERVICE', 'nvarchar(100)', 'NOT NULL', nil],
      ['SERVICE_RULE', 'SERVICE_RULE', 'int', 'NOT NULL', nil],
      ['SUBTYPE', 'SUBTYPE', 'nvarchar(100)', 'NOT NULL', nil],
      ['QUANTITY', 'QUANTITY', 'float', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: '_JobCost',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
