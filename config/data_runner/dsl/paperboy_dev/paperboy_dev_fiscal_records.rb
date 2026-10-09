# frozen_string_literal: true

[
  'Paperboy_dev_fiscal_records',
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
      schema: 'aim',
      table: 'fiscal_records',
      local: 'paperboy_dev_fiscal_records.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['invoice_id', 'invoice_id', 'bigint', 'NOT NULL', nil],
      ['status', 'status', 'nvarchar(20)', 'NOT NULL', nil],
      ['hold_reason', 'hold_reason', 'nvarchar(500)', 'NULL', nil],
      ['pay_doc_number', 'pay_doc_number', 'nvarchar(100)', 'NULL', nil],
      ['check_number', 'check_number', 'nvarchar(50)', 'NULL', nil],
      ['check_date', 'check_date', 'date', 'NULL', nil],
      ['credit_amount', 'credit_amount', 'decimal(15,2)', 'NULL', nil],
      ['description', 'description', 'nvarchar(max)', 'NULL', nil],
      ['exported_at', 'exported_at', 'datetime2(6)', 'NULL', nil],
      ['archived_at', 'archived_at', 'datetime2(6)', 'NULL', nil],
      ['updated_by', 'updated_by', 'nvarchar(255)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['tags', 'tags', 'nvarchar(500)', 'NULL', nil],
      ['stamped_at', 'stamped_at', 'datetime2(6)', 'NULL', nil],
      ['stamp_error', 'stamp_error', 'nvarchar(500)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'aim',
        table: 'fiscal_records',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
