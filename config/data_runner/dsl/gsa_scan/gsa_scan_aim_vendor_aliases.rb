# frozen_string_literal: true

[
  'Gsa_scan_aim_vendor_aliases',
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
      table: 'Aim_Vendor_Aliases',
      local: 'gsa_scan_aim_vendor_aliases.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['ExtractedName', 'ExtractedName', 'varchar(255)', 'NOT NULL', nil],
      ['NormalizedName', 'NormalizedName', 'varchar(255)', 'NOT NULL', nil],
      ['DateLearned', 'DateLearned', 'datetime', 'NULL', nil],
      ['Notes', 'Notes', 'nvarchar(max)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'Aim_Vendor_Aliases',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
