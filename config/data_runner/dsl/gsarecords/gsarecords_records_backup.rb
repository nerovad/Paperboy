# frozen_string_literal: true

[
  'Gsarecords_records_backup',
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
      name: 'gsarecords'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSARecords',
      schema: 'dbo',
      table: 'Records_Backup',
      local: 'gsarecords_records_backup.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['TYPE', 'TYPE', 'nvarchar(3)', 'NULL', nil],
      ['CUNIT', 'CUNIT', 'nvarchar(4)', 'NULL', nil],
      ['COBJECT', 'COBJECT', 'nvarchar(4)', 'NULL', nil],
      ['CACTIVITY', 'CACTIVITY', 'nvarchar(4)', 'NULL', nil],
      ['CFUNCTION', 'CFUNCTION', 'nvarchar(4)', 'NULL', nil],
      ['CPROGRAM', 'CPROGRAM', 'nvarchar(10)', 'NULL', nil],
      ['CPHASE', 'CPHASE', 'nvarchar(6)', 'NULL', nil],
      ['CTASK', 'CTASK', 'nvarchar(4)', 'NULL', nil],
      ['AMOUNT', 'AMOUNT', 'float', 'NULL', nil],
      ['SUNIT', 'SUNIT', 'nvarchar(4)', 'NULL', nil],
      ['SOBJECT', 'SOBJECT', 'nvarchar(4)', 'NULL', nil],
      ['SACTIVITY', 'SACTIVITY', 'nvarchar(4)', 'NULL', nil],
      ['SFUNCTION', 'SFUNCTION', 'nvarchar(4)', 'NULL', nil],
      ['SPROGRAM', 'SPROGRAM', 'nvarchar(10)', 'NULL', nil],
      ['SPHASE', 'SPHASE', 'nvarchar(6)', 'NULL', nil],
      ['STASK', 'STASK', 'nvarchar(4)', 'NULL', nil],
      ['POSTING_REF', 'POSTING_REF', 'nvarchar(20)', 'NULL', nil],
      ['SERVICE', 'SERVICE', 'nvarchar(15)', 'NULL', nil],
      ['DATE', 'DATE', 'datetime2(7)', 'NULL', nil],
      ['DOC_NMBR', 'DOC_NMBR', 'nvarchar(50)', 'NULL', nil],
      ['DESCRIPTION', 'DESCRIPTION', 'nvarchar(100)', 'NULL', nil],
      ['OTHER1', 'OTHER1', 'nvarchar(50)', 'NULL', nil],
      ['OTHER2', 'OTHER2', 'nvarchar(50)', 'NULL', nil],
      ['OTHER3', 'OTHER3', 'nvarchar(50)', 'NULL', nil],
      ['QUANTITY', 'QUANTITY', 'float', 'NULL', nil],
      ['RATE', 'RATE', 'float', 'NULL', nil],
      ['COST', 'COST', 'float', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'rcd',
        table: 'Records_Backup',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
