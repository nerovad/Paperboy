# frozen_string_literal: true

[
  'Paperboy_dev_dam_assets',
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
    dependency: 'Paperboy_dev_dam_storage_locations',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'dam_assets',
      local: 'paperboy_dev_dam_assets.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['title', 'title', 'nvarchar(4000)', 'NOT NULL', nil],
      ['description', 'description', 'nvarchar(max)', 'NULL', nil],
      ['filename', 'filename', 'nvarchar(4000)', 'NULL', nil],
      ['media_type', 'media_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['format', 'format', 'nvarchar(4000)', 'NULL', nil],
      ['content_type', 'content_type', 'nvarchar(4000)', 'NULL', nil],
      ['byte_size', 'byte_size', 'bigint', 'NULL', nil],
      ['checksum', 'checksum', 'nvarchar(4000)', 'NULL', nil],
      ['storage_location_id', 'storage_location_id', 'bigint', 'NULL', nil],
      ['storage_path', 'storage_path', 'nvarchar(4000)', 'NULL', nil],
      ['width', 'width', 'int', 'NULL', nil],
      ['height', 'height', 'int', 'NULL', nil],
      ['duration_seconds', 'duration_seconds', 'int', 'NULL', nil],
      ['uploaded_by_id', 'uploaded_by_id', 'nvarchar(4000)', 'NULL', nil],
      ['uploaded_by_name', 'uploaded_by_name', 'nvarchar(4000)', 'NULL', nil],
      ['status', 'status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['ingested_at', 'ingested_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['source_path', 'source_path', 'nvarchar(4000)', 'NULL', nil],
      ['source_key', 'source_key', 'nvarchar(64)', 'NULL', nil],
      ['storage_kind', 'storage_kind', 'nvarchar(4000)', 'NOT NULL', nil],
      ['derivative_state', 'derivative_state', 'nvarchar(4000)', 'NOT NULL', nil],
      ['derivative_error', 'derivative_error', 'nvarchar(max)', 'NULL', nil],
      ['external_ref', 'external_ref', 'nvarchar(4000)', 'NULL', nil],
      ['agency_id', 'agency_id', 'nvarchar(4000)', 'NULL', nil],
      ['division_id', 'division_id', 'nvarchar(4000)', 'NULL', nil],
      ['department_id', 'department_id', 'nvarchar(4000)', 'NULL', nil],
      ['unit_id', 'unit_id', 'nvarchar(4000)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'dam_assets',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
