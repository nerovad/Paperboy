# frozen_string_literal: true

[
  'Gsabss_digital_services',
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
      table: 'digital_services',
      local: 'gsabss_digital_services.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['type', 'type', 'varchar(3)', 'NOT NULL', nil],
      ['cunit', 'cunit', 'varchar(4)', 'NOT NULL', nil],
      ['cobject', 'cobject', 'int', 'NOT NULL', nil],
      ['cactivity', 'cactivity', 'varchar(4)', 'NULL', nil],
      ['cfunction', 'cfunction', 'varchar(4)', 'NULL', nil],
      ['cprogram', 'cprogram', 'varchar(10)', 'NULL', nil],
      ['cphase', 'cphase', 'varchar(6)', 'NULL', nil],
      ['ctask', 'ctask', 'varchar(4)', 'NULL', nil],
      ['amount', 'amount', 'float', 'NULL', nil],
      ['sunit', 'sunit', 'varchar(4)', 'NOT NULL', nil],
      ['sobject', 'sobject', 'int', 'NOT NULL', nil],
      ['sactivity', 'sactivity', 'varchar(4)', 'NULL', nil],
      ['sfunction', 'sfunction', 'varchar(4)', 'NULL', nil],
      ['sprogram', 'sprogram', 'varchar(10)', 'NULL', nil],
      ['sphase', 'sphase', 'varchar(6)', 'NULL', nil],
      ['stask', 'stask', 'varchar(4)', 'NULL', nil],
      ['posting_ref', 'posting_ref', 'varchar(20)', 'NOT NULL', nil],
      ['service', 'service', 'varchar(15)', 'NOT NULL', nil],
      ['date', 'date', 'date', 'NOT NULL', nil],
      ['doc_nmbr', 'doc_nmbr', 'varchar(50)', 'NULL', nil],
      ['description', 'description', 'varchar(50)', 'NULL', nil],
      ['other1', 'other1', 'varchar(50)', 'NULL', nil],
      ['other2', 'other2', 'varchar(50)', 'NULL', nil],
      ['other3', 'other3', 'varchar(50)', 'NULL', nil],
      ['quantity', 'quantity', 'float', 'NULL', nil],
      ['rate', 'rate', 'float', 'NULL', nil],
      ['cost', 'cost', 'float', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'digital_services',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
