# frozen_string_literal: true

[
  'Gsap2m_billingdata',
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
      table: 'BillingData',
      local: 'gsap2m_billingdata.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['CUNIT', 'CUNIT', 'nvarchar(4)', 'NULL', nil],
      ['OBJECT', 'OBJECT', 'nvarchar(4)', 'NULL', nil],
      ['ACTV', 'ACTV', 'nvarchar(4)', 'NULL', nil],
      ['FUNC', 'FUNC', 'nvarchar(4)', 'NULL', nil],
      ['CPROJ', 'CPROJ', 'nvarchar(10)', 'NULL', nil],
      ['PROGRAM', 'PROGRAM', 'nvarchar(10)', 'NULL', nil],
      ['PHASE', 'PHASE', 'nvarchar(6)', 'NULL', nil],
      ['TASK', 'TASK', 'nvarchar(4)', 'NULL', nil],
      ['AMOUNT', 'AMOUNT', 'float', 'NULL', nil],
      ['SERVICE', 'SERVICE', 'varchar(3)', 'NOT NULL', nil],
      ['SUNIT', 'SUNIT', 'varchar(4)', 'NOT NULL', nil],
      ['REVENUE', 'REVENUE', 'varchar(4)', 'NOT NULL', nil],
      ['POSTING REF', 'POSTING REF', 'nvarchar(4000)', 'NULL', nil],
      ['DATE', 'DATE', 'date', 'NULL', nil],
      ['OMS NUMBER', 'OMS NUMBER', 'int', 'NULL', nil],
      ['JOBID', 'JOBID', 'varchar(16)', 'NULL', nil],
      ['DESCRIPTION', 'DESCRIPTION', 'nvarchar(100)', 'NULL', nil],
      ['QUANTITY', 'QUANTITY', 'int', 'NULL', nil],
      ['MANIFEST Qty', 'MANIFEST Qty', 'int', 'NOT NULL', nil],
      ['UAA Qty', 'UAA Qty', 'int', 'NOT NULL', nil],
      ['FULL POSTAGE RATE', 'FULL POSTAGE RATE', 'float', 'NULL', nil],
      ['GRAPHICS RATE', 'GRAPHICS RATE', 'float', 'NOT NULL', nil],
      ['ACTUAL POSTAGE', 'ACTUAL POSTAGE', 'numeric(12,3)', 'NULL', nil],
      ['FULL POSTAGE SUM', 'FULL POSTAGE SUM', 'float', 'NULL', nil],
      ['P2M FEES', 'P2M FEES', 'numeric(9,3)', 'NULL', nil],
      ['TOTAL JOB COST', 'TOTAL JOB COST', 'numeric(13,3)', 'NULL', nil],
      ['PostageSavings', 'PostageSavings', 'float', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'BillingData',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
