# frozen_string_literal: true

[
  'Paperboy_dev_dam_ingest_failures',
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
    dependency: 'Paperboy_dev_dam_storage_locations',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'dam_ingest_failures',
      local: 'paperboy_dev_dam_ingest_failures.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['storage_location_id', 'storage_location_id', 'bigint', 'NOT NULL', nil],
      ['source_key', 'source_key', 'nvarchar(64)', 'NOT NULL', nil],
      ['source_path', 'source_path', 'nvarchar(4000)', 'NULL', nil],
      ['reason', 'reason', 'nvarchar(max)', 'NULL', nil],
      ['attempts', 'attempts', 'int', 'NOT NULL', nil],
      ['last_failed_at', 'last_failed_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'dam_ingest_failures',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
