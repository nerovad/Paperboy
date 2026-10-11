# frozen_string_literal: true

[
  'Paperboy_dev_coding_rule_changes',
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
      table: 'coding_rule_changes',
      local: 'paperboy_dev_coding_rule_changes.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['coding_rule_id', 'coding_rule_id', 'bigint', 'NOT NULL', nil],
      ['kind', 'kind', 'nvarchar(20)', 'NOT NULL', nil],
      ['field', 'field', 'nvarchar(40)', 'NULL', nil],
      ['before', 'before', 'nvarchar(max)', 'NULL', nil],
      ['after', 'after', 'nvarchar(max)', 'NULL', nil],
      ['changed_by', 'changed_by', 'nvarchar(255)', 'NOT NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'aim',
        table: 'coding_rule_changes',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
