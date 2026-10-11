# frozen_string_literal: true

[
  'Gsa_scan_hsa_adopt_adoptioncards',
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
      table: 'HSA_Adopt_AdoptionCards',
      local: 'gsa_scan_hsa_adopt_adoptioncards.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['ID', 'ID', 'int', 'IDENTITY(1,1) NOT NULL', nil],
      ['CardType', 'CardType', 'nvarchar(20)', 'NOT NULL', nil],
      ['Child_BirthLast', 'Child_BirthLast', 'nvarchar(200)', 'NULL', nil],
      ['Child_BirthFirst', 'Child_BirthFirst', 'nvarchar(200)', 'NULL', nil],
      ['Child_AdoptLast', 'Child_AdoptLast', 'nvarchar(200)', 'NULL', nil],
      ['Child_AdoptFirst', 'Child_AdoptFirst', 'nvarchar(200)', 'NULL', nil],
      ['Child_DOB', 'Child_DOB', 'date', 'NULL', nil],
      ['BirthParent_1_Last', 'BirthParent_1_Last', 'nvarchar(200)', 'NULL', nil],
      ['BirthParent_1_First', 'BirthParent_1_First', 'nvarchar(200)', 'NULL', nil],
      ['BirthParent_2_Last', 'BirthParent_2_Last', 'nvarchar(200)', 'NULL', nil],
      ['BirthParent_2_First', 'BirthParent_2_First', 'nvarchar(200)', 'NULL', nil],
      ['AdoptParent_1_Last', 'AdoptParent_1_Last', 'nvarchar(200)', 'NULL', nil],
      ['AdoptParent_1_First', 'AdoptParent_1_First', 'nvarchar(200)', 'NULL', nil],
      ['AdoptParent_2_Last', 'AdoptParent_2_Last', 'nvarchar(200)', 'NULL', nil],
      ['AdoptParent_2_First', 'AdoptParent_2_First', 'nvarchar(200)', 'NULL', nil],
      ['Case_Number', 'Case_Number', 'nvarchar(200)', 'NULL', nil],
      ['CloseDate', 'CloseDate', 'date', 'NULL', nil],
      ['FinalDate_FinalDecree', 'FinalDate_FinalDecree', 'date', 'NULL', nil],
      ['VEN_Number', 'VEN_Number', 'nvarchar(200)', 'NULL', nil],
      ['A_Number', 'A_Number', 'nvarchar(200)', 'NULL', nil],
      ['Notes', 'Notes', 'nvarchar(max)', 'NULL', nil],
      ['Filepath', 'Filepath', 'nvarchar(400)', 'NULL', nil],
      ['CreatedAtUtc', 'CreatedAtUtc', 'datetime2(0)', 'NOT NULL', nil],
      ['CreatedBy', 'CreatedBy', 'sysname', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'HSA_Adopt_AdoptionCards',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
