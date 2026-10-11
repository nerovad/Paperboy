# frozen_string_literal: true

[
  'Paperboy_dev_records_email_contacts',
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
      table: 'records_email_contacts',
      local: 'paperboy_dev_records_email_contacts.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['table_slug', 'table_slug', 'nvarchar(100)', 'NOT NULL', nil],
      ['column_name', 'column_name', 'nvarchar(100)', 'NOT NULL', nil],
      ['match_value', 'match_value', 'nvarchar(200)', 'NOT NULL', nil],
      ['email', 'email', 'nvarchar(255)', 'NOT NULL', nil],
      ['created_by_employee_id', 'created_by_employee_id', 'int', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'records_email_contacts',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
