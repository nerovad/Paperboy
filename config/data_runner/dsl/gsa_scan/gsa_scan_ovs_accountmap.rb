# frozen_string_literal: true

[
  'Gsa_scan_ovs_accountmap',
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
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSA Scan',
      schema: 'dbo',
      table: 'OVS_AccountMap',
      local: 'gsa_scan_ovs_accountmap.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['Account', 'Account', 'nvarchar(100)', 'NOT NULL', nil],
      ['BU', 'BU', 'varchar(10)', 'NULL', nil],
      ['ProfileType', 'ProfileType', 'nvarchar(100)', 'NULL', nil],
      ['Notes', 'Notes', 'nvarchar(200)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'OVS_AccountMap',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
