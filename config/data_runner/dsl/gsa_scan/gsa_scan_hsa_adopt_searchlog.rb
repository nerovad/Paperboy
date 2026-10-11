# frozen_string_literal: true

[
  'Gsa_scan_hsa_adopt_searchlog',
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
      table: 'HSA_Adopt_SearchLog',
      local: 'gsa_scan_hsa_adopt_searchlog.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['SearchID', 'SearchID', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['SearchedAtUtc', 'SearchedAtUtc', 'datetime2(0)', 'NOT NULL', nil],
      ['LoginName', 'LoginName', 'sysname', 'NOT NULL', nil],
      ['AppUser', 'AppUser', 'nvarchar(200)', 'NULL', nil],
      ['HostName', 'HostName', 'nvarchar(200)', 'NULL', nil],
      ['AppName', 'AppName', 'nvarchar(200)', 'NULL', nil],
      ['ClientIP', 'ClientIP', 'nvarchar(48)', 'NULL', nil],
      ['Reason', 'Reason', 'nvarchar(200)', 'NULL', nil],
      ['P_LastName', 'P_LastName', 'nvarchar(200)', 'NULL', nil],
      ['P_FirstName', 'P_FirstName', 'nvarchar(200)', 'NULL', nil],
      ['P_CaseNumber', 'P_CaseNumber', 'nvarchar(200)', 'NULL', nil],
      ['P_VEN_or_A', 'P_VEN_or_A', 'nvarchar(200)', 'NULL', nil],
      ['P_DOB', 'P_DOB', 'date', 'NULL', nil],
      ['P_DOBYear', 'P_DOBYear', 'int', 'NULL', nil],
      ['P_AnyText', 'P_AnyText', 'nvarchar(200)', 'NULL', nil],
      ['P_Fuzzy', 'P_Fuzzy', 'bit', 'NULL', nil],
      ['P_DOBFuzzy', 'P_DOBFuzzy', 'bit', 'NULL', nil],
      ['P_NameRole', 'P_NameRole', 'nvarchar(20)', 'NULL', nil],
      ['P_Names', 'P_Names', 'nvarchar(400)', 'NULL', nil],
      ['P_CloseDate', 'P_CloseDate', 'date', 'NULL', nil],
      ['P_FinalDate', 'P_FinalDate', 'date', 'NULL', nil],
      ['P_AnyDate', 'P_AnyDate', 'date', 'NULL', nil],
      ['P_Anywhere', 'P_Anywhere', 'nvarchar(400)', 'NULL', nil],
      ['P_CardType', 'P_CardType', 'nvarchar(20)', 'NULL', nil],
      ['RowsReturned', 'RowsReturned', 'int', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'HSA_Adopt_SearchLog',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
