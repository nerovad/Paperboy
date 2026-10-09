# frozen_string_literal: true

[
  'Paperboy_dev_records_email_deliveries',
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
      table: 'records_email_deliveries',
      local: 'paperboy_dev_records_email_deliveries.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['table_slug', 'table_slug', 'nvarchar(100)', 'NOT NULL', nil],
      ['records_email_rule_id', 'records_email_rule_id', 'bigint', 'NULL', nil],
      ['subject', 'subject', 'nvarchar(4000)', 'NULL', nil],
      ['recipients', 'recipients', 'nvarchar(max)', 'NULL', nil],
      ['row_count', 'row_count', 'int', 'NOT NULL', nil],
      ['group_value', 'group_value', 'nvarchar(4000)', 'NULL', nil],
      ['sent_by_employee_id', 'sent_by_employee_id', 'nvarchar(4000)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'records_email_deliveries',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
