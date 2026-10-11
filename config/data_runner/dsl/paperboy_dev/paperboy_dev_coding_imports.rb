# frozen_string_literal: true

[
  'Paperboy_dev_coding_imports',
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
      schema: 'aim',
      table: 'coding_imports',
      local: 'paperboy_dev_coding_imports.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['agency', 'agency', 'nvarchar(3)', 'NOT NULL', nil],
      ['file_name', 'file_name', 'nvarchar(260)', 'NOT NULL', nil],
      ['imported_by', 'imported_by', 'nvarchar(255)', 'NOT NULL', nil],
      ['effective_option', 'effective_option', 'nvarchar(20)', 'NOT NULL', nil],
      ['effective_from', 'effective_from', 'date', 'NULL', nil],
      ['row_count', 'row_count', 'int', 'NOT NULL', nil],
      ['loaded_count', 'loaded_count', 'int', 'NOT NULL', nil],
      ['refused_count', 'refused_count', 'int', 'NOT NULL', nil],
      ['retired_count', 'retired_count', 'int', 'NOT NULL', nil],
      ['report', 'report', 'nvarchar(max)', 'NULL', nil],
      ['undone_at', 'undone_at', 'datetime2(6)', 'NULL', nil],
      ['undone_by', 'undone_by', 'nvarchar(255)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['status', 'status', 'nvarchar(20)', 'NOT NULL', nil],
      ['file_content', 'file_content', 'nvarchar(max)', 'NULL', nil],
      ['default_unit', 'default_unit', 'nvarchar(10)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'aim',
        table: 'coding_imports',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
