# frozen_string_literal: true

[
  'Gsa_scan_hsa_adopt_adoptioncardsnorm',
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
      table: 'HSA_Adopt_AdoptionCardsNorm',
      local: 'gsa_scan_hsa_adopt_adoptioncardsnorm.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['ID', 'ID', 'int', 'NOT NULL', nil],
      ['CardType', 'CardType', 'nvarchar(20)', 'NOT NULL', nil],
      ['Child_DOB', 'Child_DOB', 'date', 'NULL', nil],
      ['CaseDigits', 'CaseDigits', 'nvarchar(100)', 'NULL', nil],
      ['NotesDigits', 'NotesDigits', 'nvarchar(100)', 'NULL', nil],
      ['VENDigits', 'VENDigits', 'nvarchar(100)', 'NULL', nil],
      ['ADigits', 'ADigits', 'nvarchar(100)', 'NULL', nil],
      ['CBL', 'CBL', 'nvarchar(200)', 'NULL', nil],
      ['CBF', 'CBF', 'nvarchar(200)', 'NULL', nil],
      ['CAL', 'CAL', 'nvarchar(200)', 'NULL', nil],
      ['CAF', 'CAF', 'nvarchar(200)', 'NULL', nil],
      ['CBF_Real', 'CBF_Real', 'nvarchar(200)', 'NULL', nil],
      ['CAF_Real', 'CAF_Real', 'nvarchar(200)', 'NULL', nil],
      ['BP1_L', 'BP1_L', 'nvarchar(200)', 'NULL', nil],
      ['BP2_L', 'BP2_L', 'nvarchar(200)', 'NULL', nil],
      ['AP1_L', 'AP1_L', 'nvarchar(200)', 'NULL', nil],
      ['AP2_L', 'AP2_L', 'nvarchar(200)', 'NULL', nil],
      ['BP1_F', 'BP1_F', 'nvarchar(200)', 'NULL', nil],
      ['BP2_F', 'BP2_F', 'nvarchar(200)', 'NULL', nil],
      ['AP1_F', 'AP1_F', 'nvarchar(200)', 'NULL', nil],
      ['AP2_F', 'AP2_F', 'nvarchar(200)', 'NULL', nil],
      ['BP1_FULL', 'BP1_FULL', 'nvarchar(401)', 'NULL', nil],
      ['BP2_FULL', 'BP2_FULL', 'nvarchar(401)', 'NULL', nil],
      ['AP1_FULL', 'AP1_FULL', 'nvarchar(401)', 'NULL', nil],
      ['AP2_FULL', 'AP2_FULL', 'nvarchar(401)', 'NULL', nil],
      ['CBL_SX', 'CBL_SX', 'char(4)', 'NULL', nil],
      ['CAL_SX', 'CAL_SX', 'char(4)', 'NULL', nil],
      ['BP1_SX', 'BP1_SX', 'char(4)', 'NULL', nil],
      ['BP2_SX', 'BP2_SX', 'char(4)', 'NULL', nil],
      ['AP1_SX', 'AP1_SX', 'char(4)', 'NULL', nil],
      ['AP2_SX', 'AP2_SX', 'char(4)', 'NULL', nil],
      ['AllNames', 'AllNames', 'nvarchar(2600)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'scan',
        table: 'HSA_Adopt_AdoptionCardsNorm',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
