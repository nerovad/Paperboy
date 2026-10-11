# frozen_string_literal: true

[
  'Gsabss_fleet_locations',
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
      table: 'fleet_locations',
      local: 'gsabss_fleet_locations.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['Id', 'Id', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['Area', 'Area', 'int', 'NOT NULL', nil],
      ['Address', 'Address', 'nvarchar(255)', 'NOT NULL', nil],
      ['City', 'City', 'nvarchar(100)', 'NOT NULL', nil],
      ['State', 'State', 'char(2)', 'NOT NULL', nil],
      ['Zip', 'Zip', 'char(5)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'fleet_locations',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
