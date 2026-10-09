# frozen_string_literal: true

[
  'Gsabss_bdmratetypes',
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
      table: 'bdmratetypes',
      local: 'gsabss_bdmratetypes.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['rateid', 'rateid', 'smallint', 'NOT NULL', nil],
      ['description', 'description', 'nvarchar(150)', 'NOT NULL', nil],
      ['uom', 'uom', 'nvarchar(15)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'bdmratetypes',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
