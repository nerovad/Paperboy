# frozen_string_literal: true

[
  'Paperboy_dev_form_subscriptions',
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
      table: 'form_subscriptions',
      local: 'paperboy_dev_form_subscriptions.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['form_type', 'form_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['grantee_type', 'grantee_type', 'nvarchar(4000)', 'NOT NULL', nil],
      ['employee_id', 'employee_id', 'nvarchar(4000)', 'NULL', nil],
      ['group_id', 'group_id', 'int', 'NULL', nil],
      ['notify_created', 'notify_created', 'bit', 'NOT NULL', nil],
      ['notify_edited', 'notify_edited', 'bit', 'NOT NULL', nil],
      ['notify_status_changed', 'notify_status_changed', 'bit', 'NOT NULL', nil],
      ['delivery_mode', 'delivery_mode', 'nvarchar(4000)', 'NOT NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['required', 'required', 'bit', 'NOT NULL', nil],
      ['notify_comment_added', 'notify_comment_added', 'bit', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'form_subscriptions',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
