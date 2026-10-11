# frozen_string_literal: true

[
  'Paperboy_dev_dam_collection_assets',
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
    dependency: %w[Paperboy_dev_dam_assets Paperboy_dev_dam_collections],
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'dam_collection_assets',
      local: 'paperboy_dev_dam_collection_assets.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['collection_id', 'collection_id', 'bigint', 'NOT NULL', nil],
      ['asset_id', 'asset_id', 'bigint', 'NOT NULL', nil],
      ['position', 'position', 'int', 'NOT NULL', nil],
      ['added_by_id', 'added_by_id', 'nvarchar(4000)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'dam_collection_assets',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
