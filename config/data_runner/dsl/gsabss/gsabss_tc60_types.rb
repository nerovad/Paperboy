# frozen_string_literal: true

[
  'Gsabss_tc60_types',
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
      table: 'TC60_Types',
      local: 'gsabss_tc60_types.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['TYPE', 'TYPE', 'varchar(3)', 'NOT NULL', nil],
      ['ACTIVE', 'ACTIVE', 'bit', 'NOT NULL', nil],
      ['NAME', 'NAME', 'varchar(30)', 'NULL', nil],
      ['funding_type', 'funding_type', 'varchar(10)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'TC60_Types',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
