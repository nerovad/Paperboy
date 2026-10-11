# frozen_string_literal: true

[
  'Paperboy_dev_osha_300a_entries',
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
    dependency: 'Paperboy_dev_osha_establishments',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'osha_300a_entries',
      local: 'paperboy_dev_osha_300a_entries.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['osha_establishment_id', 'osha_establishment_id', 'bigint', 'NOT NULL', nil],
      ['year', 'year', 'int', 'NOT NULL', nil],
      ['annual_average_employees', 'annual_average_employees', 'int', 'NOT NULL', nil],
      ['total_hours_worked', 'total_hours_worked', 'bigint', 'NOT NULL', nil],
      ['change_reason', 'change_reason', 'nvarchar(100)', 'NULL', nil],
      ['submitted_at', 'submitted_at', 'datetime2(6)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['submitted_payload', 'submitted_payload', 'nvarchar(max)', 'NULL', nil],
      ['submission_response', 'submission_response', 'nvarchar(max)', 'NULL', nil],
      ['submitted_by_id', 'submitted_by_id', 'nvarchar(4000)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'osha_300a_entries',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
