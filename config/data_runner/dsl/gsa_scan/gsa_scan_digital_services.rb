# frozen_string_literal: true

[
  'Gsa_scan_digital_services',
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
      name: 'gsa_scan'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSA Scan',
      schema: 'dbo',
      table: 'Digital_Services',
      local: 'gsa_scan_digital_services.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['TYPE', 'TYPE', 'nvarchar(50)', 'NULL', nil],
      ['CUNIT', 'CUNIT', 'nvarchar(50)', 'NULL', nil],
      ['COBJECT', 'COBJECT', 'nvarchar(50)', 'NULL', nil],
      ['CACTIVITY', 'CACTIVITY', 'nvarchar(50)', 'NULL', nil],
      ['CFUNCTION', 'CFUNCTION', 'nvarchar(50)', 'NULL', nil],
      ['CPROGRAM', 'CPROGRAM', 'nvarchar(50)', 'NULL', nil],
      ['CPHASE', 'CPHASE', 'nvarchar(50)', 'NULL', nil],
      ['CTASK', 'CTASK', 'nvarchar(50)', 'NULL', nil],
      ['AMOUNT', 'AMOUNT', 'float', 'NULL', nil],
      ['SUNIT', 'SUNIT', 'nvarchar(50)', 'NULL', nil],
      ['SOBJECT', 'SOBJECT', 'nvarchar(50)', 'NULL', nil],
      ['SACTIVITY', 'SACTIVITY', 'nvarchar(50)', 'NULL', nil],
      ['SFUNCTION', 'SFUNCTION', 'nvarchar(50)', 'NULL', nil],
      ['SPROGRAM', 'SPROGRAM', 'nvarchar(50)', 'NULL', nil],
      ['SPHASE', 'SPHASE', 'nvarchar(50)', 'NULL', nil],
      ['STASK', 'STASK', 'nvarchar(50)', 'NULL', nil],
      ['POSTING_REF', 'POSTING_REF', 'nvarchar(50)', 'NULL', nil],
      ['SERVICE', 'SERVICE', 'nvarchar(50)', 'NULL', nil],
      ['DATE', 'DATE', 'datetime2(7)', 'NULL', nil],
      ['DOC_NMBR', 'DOC_NMBR', 'nvarchar(50)', 'NULL', nil],
      ['DESCRIPTION', 'DESCRIPTION', 'nvarchar(50)', 'NULL', nil],
      ['OTHER1', 'OTHER1', 'nvarchar(100)', 'NULL', nil],
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
        schema: 'scan',
        table: 'Digital_Services',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
