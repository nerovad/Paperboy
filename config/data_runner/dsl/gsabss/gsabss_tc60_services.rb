# frozen_string_literal: true

[
  'Gsabss_tc60_services',
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
      table: 'tc60_services',
      local: 'gsabss_tc60_services.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['year', 'year', 'nvarchar(4)', 'NOT NULL', nil],
      ['type', 'type', 'nvarchar(3)', 'NOT NULL', nil],
      ['sunit', 'sunit', 'nvarchar(4)', 'NOT NULL', nil],
      ['sobject', 'sobject', 'int', 'NOT NULL', nil],
      ['sactivity', 'sactivity', 'nvarchar(4)', 'NOT NULL', nil],
      ['sfunction', 'sfunction', 'nvarchar(4)', 'NOT NULL', nil],
      ['sprogram', 'sprogram', 'nvarchar(10)', 'NOT NULL', nil],
      ['sphase', 'sphase', 'nvarchar(6)', 'NULL', nil],
      ['stask', 'stask', 'nvarchar(4)', 'NULL', nil],
      ['service', 'service', 'varchar(25)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'tc60_services',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
