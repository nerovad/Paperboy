# frozen_string_literal: true

[
  'Gsa_scan_timetrackinginterval',
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
      name: 'gsa_scan'
    },
    dependency: 'Gsa_scan_timetrackingsession',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSA Scan',
      schema: 'dbo',
      table: 'TimeTrackingInterval',
      local: 'gsa_scan_timetrackinginterval.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['SessionID', 'SessionID', 'bigint', 'NOT NULL', nil],
      ['IntervalNumber', 'IntervalNumber', 'int', 'NOT NULL', nil],
      ['StartedAtUtc', 'StartedAtUtc', 'datetime2(3)', 'NOT NULL', nil],
      ['EndedAtUtc', 'EndedAtUtc', 'datetime2(3)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'TimeTrackingInterval',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
