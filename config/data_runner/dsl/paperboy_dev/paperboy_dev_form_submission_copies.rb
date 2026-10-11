# frozen_string_literal: true

[
  'Paperboy_dev_form_submission_copies',
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
      schema: 'dbo',
      table: 'form_submission_copies',
      local: 'paperboy_dev_form_submission_copies.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['submission_type', 'submission_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['submission_id', 'submission_id', 'bigint', 'NOT NULL', nil],
      ['recipient_employee_id', 'recipient_employee_id', 'int', 'NOT NULL', nil],
      ['delivered_via', 'delivered_via', 'nvarchar(4000)', 'NOT NULL', nil],
      ['dismissed_at', 'dismissed_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'form_submission_copies',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
