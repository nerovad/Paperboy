# frozen_string_literal: true

[
  'Gsap2m_services',
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
      table: 'Services',
      local: 'gsap2m_services.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['Id', 'Id', 'int', 'IDENTITY(0,1) NOT NULL', nil],
      ['ServiceType', 'ServiceType', 'varchar(32)', 'NULL', nil],
      ['Service', 'Service', 'varchar(16)', 'NULL', nil],
      ['SUnit', 'SUnit', 'int', 'NULL', nil],
      ['Revenue', 'Revenue', 'int', 'NULL', nil],
      ['PostingRef', 'PostingRef', 'varchar(16)', 'NULL', nil],
      ['DOC_NMBR', 'DOC_NMBR', 'varchar(16)', 'NULL', nil],
      ['Descriptn', 'Descriptn', 'varchar(16)', 'NULL', nil],
      ['DefaultValue', 'DefaultValue', 'decimal(9,3)', 'NULL', nil],
      ['Object', 'Object', 'smallint', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'Services',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
