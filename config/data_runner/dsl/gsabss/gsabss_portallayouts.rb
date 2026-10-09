# frozen_string_literal: true

[
  'Gsabss_portallayouts',
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
      schema: 'website',
      table: 'PortalLayouts',
      local: 'gsabss_portallayouts.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['employee_id', 'employee_id', 'int', 'NOT NULL', nil],
      ['tool_keys', 'tool_keys', 'nvarchar(max)', 'NOT NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'website',
        table: 'PortalLayouts',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
