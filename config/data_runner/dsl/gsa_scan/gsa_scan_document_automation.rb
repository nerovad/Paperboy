# frozen_string_literal: true

[
  'Gsa_scan_document_automation',
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
      name: 'gsa_scan'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSA Scan',
      schema: 'dbo',
      table: 'document_automation',
      local: 'gsa_scan_document_automation.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['type', 'type', 'nvarchar(3)', 'NULL', nil],
      ['cunit', 'cunit', 'nvarchar(4)', 'NULL', nil],
      ['cobject', 'cobject', 'nvarchar(4)', 'NULL', nil],
      ['cactivity', 'cactivity', 'nvarchar(4)', 'NULL', nil],
      ['cfunction', 'cfunction', 'nvarchar(4)', 'NULL', nil],
      ['cprogram', 'cprogram', 'nvarchar(10)', 'NULL', nil],
      ['cphase', 'cphase', 'nvarchar(6)', 'NULL', nil],
      ['ctask', 'ctask', 'nvarchar(4)', 'NULL', nil],
      ['amount', 'amount', 'float', 'NULL', nil],
      ['sunit', 'sunit', 'nvarchar(4)', 'NULL', nil],
      ['sobject', 'sobject', 'nvarchar(4)', 'NULL', nil],
      ['sactivity', 'sactivity', 'nvarchar(4)', 'NULL', nil],
      ['sfunction', 'sfunction', 'nvarchar(4)', 'NULL', nil],
      ['sprogram', 'sprogram', 'nvarchar(10)', 'NULL', nil],
      ['sphase', 'sphase', 'nvarchar(6)', 'NULL', nil],
      ['stask', 'stask', 'nvarchar(4)', 'NULL', nil],
      ['posting_ref', 'posting_ref', 'nvarchar(20)', 'NULL', nil],
      ['service', 'service', 'nvarchar(15)', 'NULL', nil],
      ['date', 'date', 'date', 'NULL', nil],
      ['doc_nmbr', 'doc_nmbr', 'nvarchar(50)', 'NULL', nil],
      ['description', 'description', 'nvarchar(100)', 'NULL', nil],
      ['other1', 'other1', 'nvarchar(50)', 'NULL', nil],
      ['other2', 'other2', 'nvarchar(50)', 'NULL', nil],
      ['other3', 'other3', 'nvarchar(50)', 'NULL', nil],
      ['quantity', 'quantity', 'float', 'NULL', nil],
      ['rate', 'rate', 'float', 'NULL', nil],
      ['cost', 'cost', 'float', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'document_automation',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
