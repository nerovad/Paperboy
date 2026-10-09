# frozen_string_literal: true

[
  'Gsabss_tc60',
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
    dependency: 'Gsabss_tc60_types',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSABSS',
      schema: 'dbo',
      table: 'TC60',
      local: 'gsabss_tc60.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['TYPE', 'TYPE', 'varchar(3)', 'NOT NULL', nil],
      ['CUNIT', 'CUNIT', 'varchar(4)', 'NOT NULL', nil],
      ['COBJECT', 'COBJECT', 'int', 'NOT NULL', nil],
      ['CACTIVITY', 'CACTIVITY', 'varchar(4)', 'NULL', nil],
      ['CFUNCTION', 'CFUNCTION', 'varchar(4)', 'NULL', nil],
      ['CPROGRAM', 'CPROGRAM', 'varchar(10)', 'NULL', nil],
      ['CPHASE', 'CPHASE', 'varchar(6)', 'NULL', nil],
      ['CTASK', 'CTASK', 'varchar(4)', 'NULL', nil],
      ['AMOUNT', 'AMOUNT', 'float', 'NULL', nil],
      ['SUNIT', 'SUNIT', 'varchar(4)', 'NOT NULL', nil],
      ['SOBJECT', 'SOBJECT', 'int', 'NOT NULL', nil],
      ['SACTIVITY', 'SACTIVITY', 'varchar(4)', 'NULL', nil],
      ['SFUNCTION', 'SFUNCTION', 'varchar(4)', 'NULL', nil],
      ['SPROGRAM', 'SPROGRAM', 'varchar(10)', 'NULL', nil],
      ['SPHASE', 'SPHASE', 'varchar(6)', 'NULL', nil],
      ['STASK', 'STASK', 'varchar(4)', 'NULL', nil],
      ['POSTING_REF', 'POSTING_REF', 'varchar(20)', 'NOT NULL', nil],
      ['SERVICE', 'SERVICE', 'varchar(25)', 'NOT NULL', nil],
      ['DATE', 'DATE', 'date', 'NOT NULL', nil],
      ['DOC_NMBR', 'DOC_NMBR', 'varchar(50)', 'NULL', nil],
      ['DESCRIPTION', 'DESCRIPTION', 'varchar(100)', 'NULL', nil],
      ['OTHER1', 'OTHER1', 'varchar(100)', 'NULL', nil],
      ['OTHER2', 'OTHER2', 'varchar(100)', 'NULL', nil],
      ['OTHER3', 'OTHER3', 'varchar(100)', 'NULL', nil],
      ['QUANTITY', 'QUANTITY', 'float', 'NULL', nil],
      ['RATE', 'RATE', 'float', 'NULL', nil],
      ['COST', 'COST', 'float', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'TC60',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
