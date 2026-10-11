# frozen_string_literal: true

[
  'Paperboy_dev_coding_lines',
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
      table: 'coding_lines',
      local: 'paperboy_dev_coding_lines.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['invoice_id', 'invoice_id', 'bigint', 'NOT NULL', nil],
      ['line_no', 'line_no', 'int', 'NOT NULL', nil],
      ['amount', 'amount', 'decimal(15,2)', 'NULL', nil],
      ['encumbrance_type', 'encumbrance_type', 'nvarchar(10)', 'NULL', nil],
      ['encumbrance_number', 'encumbrance_number', 'nvarchar(100)', 'NULL', nil],
      ['ma_number', 'ma_number', 'nvarchar(100)', 'NULL', nil],
      ['vendor_code', 'vendor_code', 'nvarchar(50)', 'NULL', nil],
      ['fund', 'fund', 'nvarchar(20)', 'NULL', nil],
      ['department', 'department', 'nvarchar(20)', 'NULL', nil],
      ['org_number', 'org_number', 'nvarchar(20)', 'NULL', nil],
      ['object_code', 'object_code', 'nvarchar(20)', 'NULL', nil],
      ['dept_object', 'dept_object', 'nvarchar(20)', 'NULL', nil],
      ['activity', 'activity', 'nvarchar(20)', 'NULL', nil],
      ['function_code', 'function_code', 'nvarchar(20)', 'NULL', nil],
      ['major_program', 'major_program', 'nvarchar(20)', 'NULL', nil],
      ['program', 'program', 'nvarchar(20)', 'NULL', nil],
      ['phase', 'phase', 'nvarchar(20)', 'NULL', nil],
      ['task', 'task', 'nvarchar(20)', 'NULL', nil],
      ['coding_rule_id', 'coding_rule_id', 'bigint', 'NULL', nil],
      ['source', 'source', 'nvarchar(20)', 'NOT NULL', nil],
      ['set_by', 'set_by', 'nvarchar(255)', 'NULL', nil],
      ['warnings', 'warnings', 'nvarchar(max)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'aim',
        table: 'coding_lines',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
