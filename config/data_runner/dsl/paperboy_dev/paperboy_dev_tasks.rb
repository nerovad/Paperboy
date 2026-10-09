# frozen_string_literal: true

[
  'Paperboy_dev_tasks',
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
      table: 'tasks',
      local: 'paperboy_dev_tasks.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['agency_id', 'agency_id', 'nvarchar(3)', 'NOT NULL', nil],
      ['task_id', 'task_id', 'nvarchar(4)', 'NOT NULL', nil],
      ['long_name', 'long_name', 'nvarchar(100)', 'NOT NULL', nil],
      ['short_name', 'short_name', 'nvarchar(50)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'tasks',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
