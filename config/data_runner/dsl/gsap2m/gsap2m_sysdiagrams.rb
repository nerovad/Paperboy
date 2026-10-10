# frozen_string_literal: true

[
  'Gsap2m_sysdiagrams',
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
      name: 'gsap2m'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSAP2M',
      schema: 'dbo',
      table: 'sysdiagrams',
      local: 'gsap2m_sysdiagrams.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['name', 'name', 'sysname', 'NOT NULL', nil],
      ['principal_id', 'principal_id', 'int', 'NOT NULL', nil],
      ['diagram_id', 'diagram_id', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['version', 'version', 'int', 'NULL', nil],
      ['definition', 'definition', 'varbinary(max)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'sysdiagrams',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
