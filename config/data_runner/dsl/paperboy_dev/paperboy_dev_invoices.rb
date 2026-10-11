# frozen_string_literal: true

[
  'Paperboy_dev_invoices',
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
      table: 'invoices',
      local: 'paperboy_dev_invoices.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['batch_id', 'batch_id', 'nvarchar(255)', 'NOT NULL', nil],
      ['business_key', 'business_key', 'nvarchar(450)', 'NULL', nil],
      ['budget_unit', 'budget_unit', 'nvarchar(10)', 'NULL', nil],
      ['submitter', 'submitter', 'nvarchar(4000)', 'NULL', nil],
      ['document_type', 'document_type', 'nvarchar(50)', 'NULL', nil],
      ['state', 'state', 'nvarchar(50)', 'NOT NULL', nil],
      ['claimed_by', 'claimed_by', 'nvarchar(4000)', 'NULL', nil],
      ['claimed_at', 'claimed_at', 'datetime2(6)', 'NULL', nil],
      ['assigned_to', 'assigned_to', 'nvarchar(4000)', 'NULL', nil],
      ['assignment_source', 'assignment_source', 'nvarchar(50)', 'NULL', nil],
      ['extracted_vendor_name', 'extracted_vendor_name', 'nvarchar(4000)', 'NULL', nil],
      ['vendor_name', 'vendor_name', 'nvarchar(4000)', 'NULL', nil],
      ['invoice_number', 'invoice_number', 'nvarchar(100)', 'NULL', nil],
      ['order_number', 'order_number', 'nvarchar(100)', 'NULL', nil],
      ['customer_number', 'customer_number', 'nvarchar(100)', 'NULL', nil],
      ['invoice_total', 'invoice_total', 'decimal(15,2)', 'NULL', nil],
      ['invoice_date', 'invoice_date', 'date', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['claimed_by_name', 'claimed_by_name', 'nvarchar(4000)', 'NULL', nil],
      ['command', 'command', 'nvarchar(20)', 'NULL', nil],
      ['attempt', 'attempt', 'int', 'NOT NULL', nil],
      ['lease_owner', 'lease_owner', 'nvarchar(100)', 'NULL', nil],
      ['lease_until', 'lease_until', 'datetime2(6)', 'NULL', nil],
      ['review_reason', 'review_reason', 'nvarchar(40)', 'NULL', nil],
      ['review_note', 'review_note', 'nvarchar(max)', 'NULL', nil],
      ['notes', 'notes', 'nvarchar(max)', 'NULL', nil],
      ['parent_id', 'parent_id', 'bigint', 'NULL', nil],
      ['source_filename', 'source_filename', 'nvarchar(260)', 'NULL', nil],
      ['source_path', 'source_path', 'nvarchar(1000)', 'NULL', nil],
      ['content_hash', 'content_hash', 'nvarchar(64)', 'NULL', nil],
      ['page_count', 'page_count', 'int', 'NULL', nil],
      ['subtotal', 'subtotal', 'decimal(15,2)', 'NULL', nil],
      ['sales_tax', 'sales_tax', 'decimal(15,2)', 'NULL', nil],
      ['extracted', 'extracted', 'nvarchar(max)', 'NULL', nil],
      ['manifest', 'manifest', 'nvarchar(max)', 'NULL', nil],
      ['split_check', 'split_check', 'bit', 'NOT NULL', nil],
      ['high_confidence', 'high_confidence', 'bit', 'NULL', nil],
      ['exported_at', 'exported_at', 'datetime2(6)', 'NULL', nil],
      ['billed_state', 'billed_state', 'nvarchar(40)', 'NULL', nil],
      ['assigned_employee_id', 'assigned_employee_id', 'int', 'NULL', nil],
      ['agency', 'agency', 'nvarchar(3)', 'NULL', nil],
      ['coded_at', 'coded_at', 'datetime2(6)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'aim',
        table: 'invoices',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
