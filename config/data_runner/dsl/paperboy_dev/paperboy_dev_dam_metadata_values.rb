# frozen_string_literal: true

[
  'Paperboy_dev_dam_metadata_values',
  {
     steps: {
      manual: {
        enabled: true,
        steps: Workflow::MANUAL_STEPS
      },
      scheduled: {
        enabled: true,
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'paperboy_dev'
    },
    dependency: 'Paperboy_dev_dam_assets',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'dam_metadata_values',
      local: 'paperboy_dev_dam_metadata_values.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['asset_id', 'asset_id', 'bigint', 'NOT NULL', nil],
      ['field_key', 'field_key', 'nvarchar(4000)', 'NOT NULL', nil],
      ['value', 'value', 'nvarchar(max)', 'NULL', nil],
      ['numeric_value', 'numeric_value', 'decimal(18,4)', 'NULL', nil],
      ['date_value', 'date_value', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'dam_metadata_values',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
