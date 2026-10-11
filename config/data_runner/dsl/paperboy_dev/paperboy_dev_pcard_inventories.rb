# frozen_string_literal: true

[
  'Paperboy_dev_pcard_inventories',
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
    dependency: 'Paperboy_dev_pcard_request_forms',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'pcard_inventories',
      local: 'paperboy_dev_pcard_inventories.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['last_name', 'last_name', 'nvarchar(4000)', 'NULL', nil],
      ['first_name', 'first_name', 'nvarchar(4000)', 'NULL', nil],
      ['agency', 'agency', 'nvarchar(4000)', 'NULL', nil],
      ['division', 'division', 'nvarchar(4000)', 'NULL', nil],
      ['mail_stop', 'mail_stop', 'nvarchar(4000)', 'NULL', nil],
      ['address', 'address', 'nvarchar(4000)', 'NULL', nil],
      ['city', 'city', 'nvarchar(4000)', 'NULL', nil],
      ['state', 'state', 'nvarchar(4000)', 'NULL', nil],
      ['zip', 'zip', 'nvarchar(4000)', 'NULL', nil],
      ['phone', 'phone', 'nvarchar(4000)', 'NULL', nil],
      ['single_purchase_limit', 'single_purchase_limit', 'decimal(10,2)', 'NULL', nil],
      ['monthly_limit', 'monthly_limit', 'decimal(10,2)', 'NULL', nil],
      ['card_number', 'card_number', 'nvarchar(4000)', 'NULL', nil],
      ['issued_date', 'issued_date', 'date', 'NULL', nil],
      ['expiration_date', 'expiration_date', 'date', 'NULL', nil],
      ['canceled_date', 'canceled_date', 'date', 'NULL', nil],
      ['agent', 'agent', 'nvarchar(4000)', 'NULL', nil],
      ['company', 'company', 'nvarchar(4000)', 'NULL', nil],
      ['division_number', 'division_number', 'nvarchar(4000)', 'NULL', nil],
      ['approver_name', 'approver_name', 'nvarchar(4000)', 'NULL', nil],
      ['org_number', 'org_number', 'nvarchar(4000)', 'NULL', nil],
      ['dept_head_agency', 'dept_head_agency', 'nvarchar(4000)', 'NULL', nil],
      ['billing_contact', 'billing_contact', 'nvarchar(4000)', 'NULL', nil],
      ['pcard_request_form_id', 'pcard_request_form_id', 'bigint', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['card_last_four', 'card_last_four', 'nvarchar(4)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'pcard_inventories',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
