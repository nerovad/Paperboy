# frozen_string_literal: true

[
  'Paperboy_dev_groups',
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
      table: 'Groups',
      local: 'paperboy_dev_groups.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['GroupID', 'GroupID', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['Group_Name', 'Group_Name', 'nvarchar(100)', 'NOT NULL', nil],
      ['Description', 'Description', 'nvarchar(500)', 'NULL', nil],
      ['Created_At', 'Created_At', 'datetime', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'Groups',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
