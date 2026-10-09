# frozen_string_literal: true

[
  'Gsa_scan_hsa_adopt_casegroups',
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
      name: 'gsa_scan'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSA Scan',
      schema: 'dbo',
      table: 'HSA_Adopt_CaseGroups',
      local: 'gsa_scan_hsa_adopt_casegroups.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['GroupID', 'GroupID', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['ChildCardID', 'ChildCardID', 'int', 'NOT NULL', nil],
      ['AdoptCardID', 'AdoptCardID', 'int', 'NULL', nil],
      ['BirthCardID', 'BirthCardID', 'int', 'NULL', nil],
      ['ScoreChildAdopt', 'ScoreChildAdopt', 'int', 'NULL', nil],
      ['ScoreChildBirth', 'ScoreChildBirth', 'int', 'NULL', nil],
      ['ScoreAdoptBirth', 'ScoreAdoptBirth', 'int', 'NULL', nil],
      ['RunnerUpAdopt', 'RunnerUpAdopt', 'int', 'NULL', nil],
      ['RunnerUpBirth', 'RunnerUpBirth', 'int', 'NULL', nil],
      ['Ambiguous', 'Ambiguous', 'bit', 'NOT NULL', nil],
      ['Status', 'Status', 'nvarchar(12)', 'NOT NULL', nil],
      ['Conflicts', 'Conflicts', 'nvarchar(500)', 'NULL', nil],
      ['ReviewedBy', 'ReviewedBy', 'nvarchar(200)', 'NULL', nil],
      ['ReviewedDate', 'ReviewedDate', 'date', 'NULL', nil],
      ['RunAtUtc', 'RunAtUtc', 'datetime2(0)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'HSA_Adopt_CaseGroups',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
