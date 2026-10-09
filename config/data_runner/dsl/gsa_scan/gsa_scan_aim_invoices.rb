# frozen_string_literal: true

[
  'Gsa_scan_aim_invoices',
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
      name: 'gsa_scan'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSA Scan',
      schema: 'dbo',
      table: 'Aim_Invoices',
      local: 'gsa_scan_aim_invoices.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['ID', 'ID', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['Budget Unit #', 'Budget Unit #', 'nvarchar(max)', 'NULL', nil],
      ['Invoice Date', 'Invoice Date', 'date', 'NULL', nil],
      ['Vendor Name', 'Vendor Name', 'nvarchar(max)', 'NULL', nil],
      ['Remit to', 'Remit to', 'nvarchar(max)', 'NULL', nil],
      ['Invoice Number', 'Invoice Number', 'nvarchar(max)', 'NULL', nil],
      ['Invoice_Amt', 'Invoice_Amt', 'nvarchar(max)', 'NULL', nil],
      ['Credit Amount', 'Credit Amount', 'nvarchar(max)', 'NULL', nil],
      ['Sales_Tax', 'Sales_Tax', 'nvarchar(max)', 'NULL', nil],
      ['BDO_DO_CT', 'BDO_DO_CT', 'nvarchar(max)', 'NULL', nil],
      ['Program_Number', 'Program_Number', 'nvarchar(max)', 'NULL', nil],
      ['Major_Program', 'Major_Program', 'nvarchar(max)', 'NULL', nil],
      ['Fund', 'Fund', 'nvarchar(max)', 'NULL', nil],
      ['Object', 'Object', 'nvarchar(max)', 'NULL', nil],
      ['Program', 'Program', 'nvarchar(max)', 'NULL', nil],
      ['Activity', 'Activity', 'nvarchar(max)', 'NULL', nil],
      ['Function', 'Function', 'nvarchar(max)', 'NULL', nil],
      ['Phase', 'Phase', 'nvarchar(max)', 'NULL', nil],
      ['Department', 'Department', 'nvarchar(max)', 'NULL', nil],
      ['Order_number', 'Order_number', 'nvarchar(max)', 'NULL', nil],
      ['Customer', 'Customer', 'nvarchar(max)', 'NULL', nil],
      ['To_reviewers', 'To_reviewers', 'nvarchar(max)', 'NULL', nil],
      ['Fusion Queue', 'Fusion Queue', 'nvarchar(max)', 'NULL', nil],
      ['Task', 'Task', 'nvarchar(max)', 'NULL', nil],
      ['BatchCreateDate', 'BatchCreateDate', 'date', 'NULL', nil],
      ['Order #', 'Order #', 'nvarchar(max)', 'NULL', nil],
      ['PO Number', 'PO Number', 'nvarchar(max)', 'NULL', nil],
      ['Account Number', 'Account Number', 'nvarchar(max)', 'NULL', nil],
      ['BatchID', 'BatchID', 'nvarchar(max)', 'NULL', nil],
      ['timestamp', 'timestamp', 'nvarchar(max)', 'NULL', nil],
      ['User Name', 'User Name', 'nvarchar(max)', 'NULL', nil],
      ['Subtotal', 'Subtotal', 'nvarchar(max)', 'NULL', nil],
      ['Source', 'Source', 'nvarchar(max)', 'NULL', nil],
      ['Approved By', 'Approved By', 'nvarchar(max)', 'NULL', nil],
      ['Invoice Status', 'Invoice Status', 'nvarchar(max)', 'NULL', nil],
      ['Processed Date', 'Processed Date', 'date', 'NULL', nil],
      ['ProcessedTimestamp', 'ProcessedTimestamp', 'datetime', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'Aim_Invoices',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
