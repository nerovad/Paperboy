# frozen_string_literal: true

[
  'Paperboy_dev_dam_publish_targets',
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
      table: 'dam_publish_targets',
      local: 'paperboy_dev_dam_publish_targets.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['key', 'key', 'nvarchar(4000)', 'NOT NULL', nil],
      ['label', 'label', 'nvarchar(4000)', 'NOT NULL', nil],
      ['provider', 'provider', 'nvarchar(4000)', 'NOT NULL', nil],
      ['enabled', 'enabled', 'bit', 'NOT NULL', nil],
      ['position', 'position', 'int', 'NOT NULL', nil],
      ['notes', 'notes', 'nvarchar(max)', 'NULL', nil],
      ['account_ref', 'account_ref', 'nvarchar(4000)', 'NULL', nil],
      ['account_label', 'account_label', 'nvarchar(4000)', 'NULL', nil],
      ['endpoint_url', 'endpoint_url', 'nvarchar(4000)', 'NULL', nil],
      ['http_method', 'http_method', 'nvarchar(4000)', 'NOT NULL', nil],
      ['headers', 'headers', 'nvarchar(max)', 'NULL', nil],
      ['body_style', 'body_style', 'nvarchar(4000)', 'NOT NULL', nil],
      ['file_field', 'file_field', 'nvarchar(4000)', 'NOT NULL', nil],
      ['default_privacy', 'default_privacy', 'nvarchar(4000)', 'NULL', nil],
      ['oauth_access_token', 'oauth_access_token', 'nvarchar(max)', 'NULL', nil],
      ['oauth_refresh_token', 'oauth_refresh_token', 'nvarchar(max)', 'NULL', nil],
      ['oauth_expires_at', 'oauth_expires_at', 'datetime2(6)', 'NULL', nil],
      ['oauth_scope', 'oauth_scope', 'nvarchar(4000)', 'NULL', nil],
      ['connected_at', 'connected_at', 'datetime2(6)', 'NULL', nil],
      ['connected_by_id', 'connected_by_id', 'nvarchar(4000)', 'NULL', nil],
      ['connected_by_name', 'connected_by_name', 'nvarchar(4000)', 'NULL', nil],
      ['last_published_at', 'last_published_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'dam_publish_targets',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
