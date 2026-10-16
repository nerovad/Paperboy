# frozen_string_literal: true

[
  'Paperboy_dev_fiscal_reports',
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
      table: 'fiscal_reports',
      local: 'paperboy_dev_fiscal_reports.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['agency_group_id', 'agency_group_id', 'bigint', 'NULL', nil],
      ['report_template_id', 'report_template_id', 'bigint', 'NULL', nil],
      ['layout_name', 'layout_name', 'nvarchar(150)', 'NOT NULL', nil],
      ['export_format', 'export_format', 'nvarchar(10)', 'NOT NULL', nil],
      ['file_name', 'file_name', 'nvarchar(255)', 'NOT NULL', nil],
      ['content', 'content', 'varbinary(max)', 'NULL', nil],
      ['invoice_count', 'invoice_count', 'int', 'NOT NULL', nil],
      ['replaces_report_id', 'replaces_report_id', 'bigint', 'NULL', nil],
      ['created_by', 'created_by', 'nvarchar(255)', 'NOT NULL', nil],
      ['expires_at', 'expires_at', 'datetime2(6)', 'NOT NULL', nil],
      ['purged_at', 'purged_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'aim',
        table: 'fiscal_reports',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
