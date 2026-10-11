# frozen_string_literal: true

[
  'Gsap2m_uspspostalrates',
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
      table: 'UspsPostalRates',
      local: 'gsap2m_uspspostalrates.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['MailClass', 'MailClass', 'nvarchar(50)', 'NOT NULL', nil],
      ['StartDate', 'StartDate', 'date', 'NOT NULL', nil],
      ['EndDate', 'EndDate', 'date', 'NOT NULL', nil],
      ['Rate', 'Rate', 'numeric(18,3)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'UspsPostalRates',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
