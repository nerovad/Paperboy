# frozen_string_literal: true

[
  'Paperboy_dev_active_storage_blobs',
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
      table: 'active_storage_blobs',
      local: 'paperboy_dev_active_storage_blobs.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['key', 'key', 'nvarchar(4000)', 'NOT NULL', nil],
      ['filename', 'filename', 'nvarchar(4000)', 'NOT NULL', nil],
      ['content_type', 'content_type', 'nvarchar(4000)', 'NULL', nil],
      ['metadata', 'metadata', 'nvarchar(max)', 'NULL', nil],
      ['service_name', 'service_name', 'nvarchar(4000)', 'NOT NULL', nil],
      ['byte_size', 'byte_size', 'bigint', 'NOT NULL', nil],
      ['checksum', 'checksum', 'nvarchar(4000)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'active_storage_blobs',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
