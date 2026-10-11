# frozen_string_literal: true

[
  'Gsa_scan_hca_bh_scanlog',
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
      table: 'HCA_BH_ScanLog',
      local: 'gsa_scan_hca_bh_scanlog.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['JobID', 'JobID', 'nvarchar(max)', 'NULL', nil],
      ['Key', 'Key', 'nvarchar(max)', 'NOT NULL', nil],
      ['Timestamp', 'Timestamp', 'smalldatetime', 'NULL', nil],
      ['BoxNumber', 'BoxNumber', 'nvarchar(max)', 'NULL', nil],
      ['Type', 'Type', 'nvarchar(max)', 'NULL', nil],
      ['ID', 'ID', 'nvarchar(max)', 'NULL', nil],
      ['Name_last', 'Name_last', 'nvarchar(max)', 'NULL', nil],
      ['Name_First', 'Name_First', 'nvarchar(max)', 'NULL', nil],
      ['DOB', 'DOB', 'nvarchar(max)', 'NULL', nil],
      ['ProgramName', 'ProgramName', 'nvarchar(max)', 'NULL', nil],
      ['ChartBeginDate', 'ChartBeginDate', 'smalldatetime', 'NULL', nil],
      ['ChartEndDate', 'ChartEndDate', 'smalldatetime', 'NULL', nil],
      ['DocumentTitle', 'DocumentTitle', 'nvarchar(max)', 'NULL', nil],
      ['Subtype', 'Subtype', 'nvarchar(max)', 'NULL', nil],
      ['VendorEmployeeGrant', 'VendorEmployeeGrant', 'nvarchar(max)', 'NULL', nil],
      ['FiscalYear', 'FiscalYear', 'nvarchar(max)', 'NULL', nil],
      ['ServiceMonth', 'ServiceMonth', 'nvarchar(max)', 'NULL', nil],
      ['ProgramCode', 'ProgramCode', 'nvarchar(max)', 'NULL', nil],
      ['DocumentNumber', 'DocumentNumber', 'nvarchar(max)', 'NULL', nil],
      ['Pagecount', 'Pagecount', 'int', 'NULL', nil],
      ['Filesize', 'Filesize', 'float', 'NULL', nil],
      ['QCMinutes', 'QCMinutes', 'decimal(6,2)', 'NULL', nil],
      ['CommittedBy', 'CommittedBy', 'nvarchar(max)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'HCA_BH_ScanLog',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
