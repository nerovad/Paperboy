# frozen_string_literal: true

[
  'Paperboy_dev_coding_rules',
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
      table: 'coding_rules',
      local: 'paperboy_dev_coding_rules.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['agency', 'agency', 'nvarchar(3)', 'NOT NULL', nil],
      ['budget_unit', 'budget_unit', 'nvarchar(10)', 'NOT NULL', nil],
      ['vendor_name', 'vendor_name', 'nvarchar(255)', 'NOT NULL', nil],
      ['vendor_key', 'vendor_key', 'nvarchar(255)', 'NOT NULL', nil],
      ['customer_number', 'customer_number', 'nvarchar(100)', 'NULL', nil],
      ['encumbrance_type', 'encumbrance_type', 'nvarchar(10)', 'NULL', nil],
      ['encumbrance_number', 'encumbrance_number', 'nvarchar(100)', 'NULL', nil],
      ['ma_number', 'ma_number', 'nvarchar(100)', 'NULL', nil],
      ['vendor_code', 'vendor_code', 'nvarchar(50)', 'NULL', nil],
      ['fund', 'fund', 'nvarchar(20)', 'NULL', nil],
      ['department', 'department', 'nvarchar(20)', 'NULL', nil],
      ['object_code', 'object_code', 'nvarchar(20)', 'NULL', nil],
      ['dept_object', 'dept_object', 'nvarchar(20)', 'NULL', nil],
      ['activity', 'activity', 'nvarchar(20)', 'NULL', nil],
      ['function_code', 'function_code', 'nvarchar(20)', 'NULL', nil],
      ['major_program', 'major_program', 'nvarchar(20)', 'NULL', nil],
      ['program', 'program', 'nvarchar(20)', 'NULL', nil],
      ['phase', 'phase', 'nvarchar(20)', 'NULL', nil],
      ['task', 'task', 'nvarchar(20)', 'NULL', nil],
      ['notes', 'notes', 'nvarchar(max)', 'NULL', nil],
      ['effective_from', 'effective_from', 'date', 'NOT NULL', nil],
      ['effective_until', 'effective_until', 'date', 'NULL', nil],
      ['import_id', 'import_id', 'bigint', 'NULL', nil],
      ['source_row', 'source_row', 'int', 'NULL', nil],
      ['retired_by_import_id', 'retired_by_import_id', 'bigint', 'NULL', nil],
      ['created_by', 'created_by', 'nvarchar(255)', 'NULL', nil],
      ['updated_by', 'updated_by', 'nvarchar(255)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['warnings', 'warnings', 'nvarchar(max)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'aim',
        table: 'coding_rules',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
