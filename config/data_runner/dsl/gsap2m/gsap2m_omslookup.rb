# frozen_string_literal: true

[
  'Gsap2m_omslookup',
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
      table: 'OMSLookup',
      local: 'gsap2m_omslookup.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['OMSNumber', 'OMSNumber', 'bigint', 'NOT NULL', nil],
      ['WhenProcessed', 'WhenProcessed', 'datetime', 'NULL', nil],
      ['Processed', 'Processed', 'bit', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'OMSLookup',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
