# frozen_string_literal: true

[
  'Paperboy_dev_vendor_aliases',
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
      name: 'paperboy_dev'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'aim',
      table: 'vendor_aliases',
      local: 'paperboy_dev_vendor_aliases.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['extracted_name', 'extracted_name', 'nvarchar(255)', 'NOT NULL', nil],
      ['normalized_name', 'normalized_name', 'nvarchar(255)', 'NOT NULL', nil],
      ['learned_by', 'learned_by', 'nvarchar(255)', 'NULL', nil],
      ['note', 'note', 'nvarchar(500)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'aim',
        table: 'vendor_aliases',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
