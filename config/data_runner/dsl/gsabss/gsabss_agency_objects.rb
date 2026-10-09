# frozen_string_literal: true

[
  'Gsabss_agency_objects',
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
      name: 'gsabss'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSABSS',
      schema: 'dbo',
      table: 'agency_objects',
      local: 'gsabss_agency_objects.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['agency_id', 'agency_id', 'nvarchar(3)', 'NOT NULL', nil],
      ['object_id', 'object_id', 'int', 'NOT NULL', nil],
      ['agency_object_code', 'agency_object_code', 'nvarchar(4)', 'NOT NULL', nil],
      ['agency_object_name', 'agency_object_name', 'nvarchar(50)', 'NOT NULL', nil],
      ['rollup_object', 'rollup_object', 'nvarchar(50)', 'NOT NULL', nil],
      ['rollup_name', 'rollup_name', 'nvarchar(50)', 'NOT NULL', nil],
      ['active', 'active', 'bit', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'agency_objects',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
