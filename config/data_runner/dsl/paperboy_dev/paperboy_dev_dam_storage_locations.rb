# frozen_string_literal: true

[
  'Paperboy_dev_dam_storage_locations',
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
      schema: 'dbo',
      table: 'dam_storage_locations',
      local: 'paperboy_dev_dam_storage_locations.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['key', 'key', 'nvarchar(4000)', 'NOT NULL', nil],
      ['label', 'label', 'nvarchar(4000)', 'NOT NULL', nil],
      ['kind', 'kind', 'nvarchar(4000)', 'NOT NULL', nil],
      ['root', 'root', 'nvarchar(4000)', 'NULL', nil],
      ['description', 'description', 'nvarchar(max)', 'NULL', nil],
      ['active', 'active', 'bit', 'NOT NULL', nil],
      ['position', 'position', 'int', 'NOT NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['default_for_uploads', 'default_for_uploads', 'bit', 'NOT NULL', nil],
      ['read_only', 'read_only', 'bit', 'NOT NULL', nil],
      ['quota_bytes', 'quota_bytes', 'bigint', 'NULL', nil],
      ['watch_path', 'watch_path', 'nvarchar(4000)', 'NULL', nil],
      ['ingest_mode', 'ingest_mode', 'nvarchar(4000)', 'NOT NULL', nil],
      ['accepted_formats', 'accepted_formats', 'nvarchar(4000)', 'NULL', nil],
      ['scan_cursor', 'scan_cursor', 'nvarchar(4000)', 'NULL', nil],
      ['ignore_patterns', 'ignore_patterns', 'nvarchar(4000)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'dam_storage_locations',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
