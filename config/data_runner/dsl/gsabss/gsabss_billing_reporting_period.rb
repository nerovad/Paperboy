# frozen_string_literal: true

[
  'Gsabss_billing_reporting_period',
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
      table: 'Billing_Reporting_Period',
      local: 'gsabss_billing_reporting_period.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['FYEAR', 'FYEAR', 'varchar(10)', 'NOT NULL', nil],
      ['APMON', 'APMON', 'varchar(4)', 'NOT NULL', nil],
      ['SDATE', 'SDATE', 'date', 'NOT NULL', nil],
      ['EDATE', 'EDATE', 'date', 'NOT NULL', nil],
      ['billing_reporting_period_id', 'billing_reporting_period_id', 'uniqueidentifier', 'NOT NULL', nil],
      ['VERSION', 'VERSION', 'int', 'NOT NULL', nil],
      ['ACTIVE', 'ACTIVE', 'bit', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'Billing_Reporting_Period',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
