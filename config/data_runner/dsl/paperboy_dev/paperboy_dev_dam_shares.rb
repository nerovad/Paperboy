# frozen_string_literal: true

[
  'Paperboy_dev_dam_shares',
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
      table: 'dam_shares',
      local: 'paperboy_dev_dam_shares.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['subject_type', 'subject_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['subject_id', 'subject_id', 'bigint', 'NOT NULL', nil],
      ['subject_label', 'subject_label', 'nvarchar(4000)', 'NULL', nil],
      ['token', 'token', 'nvarchar(4000)', 'NOT NULL', nil],
      ['permission', 'permission', 'nvarchar(4000)', 'NOT NULL', nil],
      ['shared_by_id', 'shared_by_id', 'nvarchar(4000)', 'NULL', nil],
      ['shared_by_name', 'shared_by_name', 'nvarchar(4000)', 'NULL', nil],
      ['recipients', 'recipients', 'nvarchar(max)', 'NULL', nil],
      ['message', 'message', 'nvarchar(max)', 'NULL', nil],
      ['expires_at', 'expires_at', 'datetime2(6)', 'NULL', nil],
      ['revoked_at', 'revoked_at', 'datetime2(6)', 'NULL', nil],
      ['last_accessed_at', 'last_accessed_at', 'datetime2(6)', 'NULL', nil],
      ['access_count', 'access_count', 'int', 'NOT NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'dam_shares',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
