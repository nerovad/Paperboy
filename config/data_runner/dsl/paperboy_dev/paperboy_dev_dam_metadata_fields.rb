# frozen_string_literal: true

[
  'Paperboy_dev_dam_metadata_fields',
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
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'dam_metadata_fields',
      local: 'paperboy_dev_dam_metadata_fields.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['key', 'key', 'nvarchar(4000)', 'NOT NULL', nil],
      ['label', 'label', 'nvarchar(4000)', 'NOT NULL', nil],
      ['field_type', 'field_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['options', 'options', 'nvarchar(max)', 'NULL', nil],
      ['description', 'description', 'nvarchar(max)', 'NULL', nil],
      ['active', 'active', 'bit', 'NOT NULL', nil],
      ['position', 'position', 'int', 'NOT NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'dam_metadata_fields',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
