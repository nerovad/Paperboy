# frozen_string_literal: true

[
  'Paperboy_dev_dam_publications',
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
    dependency: %w[Paperboy_dev_dam_assets Paperboy_dev_dam_publish_targets],
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'dam_publications',
      local: 'paperboy_dev_dam_publications.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['asset_id', 'asset_id', 'bigint', 'NOT NULL', nil],
      ['publish_target_id', 'publish_target_id', 'bigint', 'NOT NULL', nil],
      ['asset_title', 'asset_title', 'nvarchar(4000)', 'NULL', nil],
      ['target_label', 'target_label', 'nvarchar(4000)', 'NULL', nil],
      ['provider', 'provider', 'nvarchar(4000)', 'NULL', nil],
      ['status', 'status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['title', 'title', 'nvarchar(4000)', 'NULL', nil],
      ['description', 'description', 'nvarchar(max)', 'NULL', nil],
      ['tags', 'tags', 'nvarchar(4000)', 'NULL', nil],
      ['privacy', 'privacy', 'nvarchar(4000)', 'NULL', nil],
      ['external_id', 'external_id', 'nvarchar(4000)', 'NULL', nil],
      ['external_url', 'external_url', 'nvarchar(4000)', 'NULL', nil],
      ['response_code', 'response_code', 'int', 'NULL', nil],
      ['error', 'error', 'nvarchar(max)', 'NULL', nil],
      ['log', 'log', 'nvarchar(max)', 'NULL', nil],
      ['attempts', 'attempts', 'int', 'NOT NULL', nil],
      ['job_id', 'job_id', 'int', 'NULL', nil],
      ['public_token', 'public_token', 'nvarchar(4000)', 'NULL', nil],
      ['requested_by_id', 'requested_by_id', 'nvarchar(4000)', 'NULL', nil],
      ['requested_by_name', 'requested_by_name', 'nvarchar(4000)', 'NULL', nil],
      ['queued_at', 'queued_at', 'datetime2(6)', 'NULL', nil],
      ['started_at', 'started_at', 'datetime2(6)', 'NULL', nil],
      ['finished_at', 'finished_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'dam_publications',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
