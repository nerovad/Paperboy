# frozen_string_literal: true

[
  'Gsabss_union_codes',
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
      table: 'union_codes',
      local: 'gsabss_union_codes.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['union_id', 'union_id', 'nvarchar(max)', 'NULL', nil],
      ['barg_unit', 'barg_unit', 'nvarchar(max)', 'NULL', nil],
      ['vchrp_union', 'vchrp_union', 'nvarchar(max)', 'NULL', nil],
      ['description', 'description', 'nvarchar(max)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'union_codes',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
