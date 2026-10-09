# frozen_string_literal: true

[
  'Gsabss_p2m_oms_upload_findings',
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
    dependency: 'Gsabss_p2m_oms_uploads',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSABSS',
      schema: 'dbo',
      table: 'p2m_oms_upload_findings',
      local: 'gsabss_p2m_oms_upload_findings.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['oms_upload_id', 'oms_upload_id', 'bigint', 'NOT NULL', nil],
      ['rule', 'rule', 'nvarchar(4000)', 'NOT NULL', nil],
      ['severity', 'severity', 'nvarchar(4000)', 'NOT NULL', nil],
      ['status', 'status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['observed_value', 'observed_value', 'nvarchar(4000)', 'NULL', nil],
      ['expected_value', 'expected_value', 'nvarchar(4000)', 'NULL', nil],
      ['message', 'message', 'nvarchar(max)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'p2m_oms_upload_findings',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
