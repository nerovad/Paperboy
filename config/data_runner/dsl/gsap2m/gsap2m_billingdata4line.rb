# frozen_string_literal: true

[
  'Gsap2m_billingdata4line',
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
      name: 'gsap2m'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSAP2M',
      schema: 'dbo',
      table: 'BillingData4Line',
      local: 'gsap2m_billingdata4line.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['CUNIT', 'CUNIT', 'smallint', 'NULL', nil],
      ['OBJECT', 'OBJECT', 'int', 'NULL', nil],
      ['ACTV', 'ACTV', 'nvarchar(50)', 'NULL', nil],
      ['FUNC', 'FUNC', 'nvarchar(50)', 'NULL', nil],
      ['PROGRAM', 'PROGRAM', 'varchar(64)', 'NULL', nil],
      ['PHASE', 'PHASE', 'varchar(64)', 'NULL', nil],
      ['TASK', 'TASK', 'varchar(64)', 'NULL', nil],
      ['SERVICE', 'SERVICE', 'varchar(16)', 'NOT NULL', nil],
      ['SUNIT', 'SUNIT', 'varchar(4)', 'NOT NULL', nil],
      ['REVENUE', 'REVENUE', 'varchar(4)', 'NOT NULL', nil],
      ['POSTING REF', 'POSTING REF', 'varchar(8)', 'NOT NULL', nil],
      ['DOC_NMBR', 'DOC_NMBR', 'varchar(6)', 'NULL', nil],
      ['DESCRIPTN', 'DESCRIPTN', 'varchar(16)', 'NULL', nil],
      ['DATE', 'DATE', 'varchar(10)', 'NOT NULL', nil],
      ['OMS NUMBER', 'OMS NUMBER', 'int', 'NULL', nil],
      ['JOBID', 'JOBID', 'varchar(max)', 'NULL', nil],
      ['DESCRIPTION', 'DESCRIPTION', 'varchar(100)', 'NULL', nil],
      ['QUANTITY', 'QUANTITY', 'int', 'NULL', nil],
      ['MANIFEST Qty', 'MANIFEST Qty', 'int', 'NOT NULL', nil],
      ['UAA Qty', 'UAA Qty', 'int', 'NOT NULL', nil],
      ['FULL POSTAGE RATE', 'FULL POSTAGE RATE', 'numeric(6,3)', 'NULL', nil],
      ['GRAPHICS RATE', 'GRAPHICS RATE', 'numeric(9,3)', 'NULL', nil],
      ['ACTUAL POSTAGE', 'ACTUAL POSTAGE', 'numeric(12,3)', 'NULL', nil],
      ['FULL POSTAGE SUM', 'FULL POSTAGE SUM', 'numeric(12,3)', 'NULL', nil],
      ['P2M FEES', 'P2M FEES', 'numeric(12,3)', 'NULL', nil],
      ['TOTAL JOB COST', 'TOTAL JOB COST', 'numeric(9,3)', 'NULL', nil],
      ['SERVICE TYPE', 'SERVICE TYPE', 'varchar(32)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'BillingData4Line',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
