# frozen_string_literal: true

[
  'Paperboy_dev_agency_groups',
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
      host: 'GSASQL16',
      database: 'Paperboy_Dev',
      schema: 'aim',
      table: 'agency_groups',
      local: 'paperboy_dev_agency_groups.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['name', 'name', 'nvarchar(100)', 'NOT NULL', nil],
      ['agency_id', 'agency_id', 'nvarchar(10)', 'NOT NULL', nil],
      ['custom', 'custom', 'bit', 'NOT NULL', nil],
      ['export_format', 'export_format', 'nvarchar(10)', 'NOT NULL', nil],
      ['export_columns', 'export_columns', 'nvarchar(max)', 'NULL', nil],
      ['hold_reasons', 'hold_reasons', 'nvarchar(max)', 'NULL', nil],
      ['tag_suggestions', 'tag_suggestions', 'nvarchar(max)', 'NULL', nil],
      ['required_fields', 'required_fields', 'nvarchar(500)', 'NULL', nil],
      ['updated_by', 'updated_by', 'nvarchar(255)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'aim',
        table: 'agency_groups',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
