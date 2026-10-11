# frozen_string_literal: true

[
  'Gsabss_sub_units',
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
      table: 'sub_units',
      local: 'gsabss_sub_units.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['agency_id', 'agency_id', 'nvarchar(3)', 'NOT NULL', nil],
      ['unit_id', 'unit_id', 'nvarchar(4)', 'NOT NULL', nil],
      ['sub_unit_id', 'sub_unit_id', 'nvarchar(4)', 'NOT NULL', nil],
      ['sub_unit_name', 'sub_unit_name', 'nvarchar(50)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'sub_units',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
