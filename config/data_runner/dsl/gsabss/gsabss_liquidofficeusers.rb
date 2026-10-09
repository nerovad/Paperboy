# frozen_string_literal: true

[
  'Gsabss_liquidofficeusers',
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
      table: 'liquidofficeusers',
      local: 'gsabss_liquidofficeusers.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['loginid', 'loginid', 'nvarchar(max)', 'NULL', nil],
      ['firstname', 'firstname', 'nvarchar(max)', 'NULL', nil],
      ['lastname', 'lastname', 'nvarchar(max)', 'NULL', nil],
      ['lastlogondate', 'lastlogondate', 'nvarchar(max)', 'NULL', nil],
      ['logoncount', 'logoncount', 'nvarchar(max)', 'NULL', nil],
      ['serverid', 'serverid', 'nvarchar(max)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'liquidofficeusers',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
