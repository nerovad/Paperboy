# frozen_string_literal: true

[
  'Gsap2m_moveresults',
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
      name: 'gsap2m'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSAP2M',
      schema: 'dbo',
      table: 'MoveResults',
      local: 'gsap2m_moveresults.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['OMSNumber', 'OMSNumber', 'int', 'NULL', nil],
      ['RECORD_ID', 'RECORD_ID', 'int', 'NULL', nil],
      ['BUSINESS', 'BUSINESS', 'nvarchar(100)', 'NULL', nil],
      ['FIRST_NAME', 'FIRST_NAME', 'nvarchar(100)', 'NULL', nil],
      ['LAST_NAME', 'LAST_NAME', 'nvarchar(150)', 'NULL', nil],
      ['ADDRESS_LINE_1', 'ADDRESS_LINE_1', 'nvarchar(100)', 'NULL', nil],
      ['ADDRESS_LINE_2', 'ADDRESS_LINE_2', 'nvarchar(100)', 'NULL', nil],
      ['CITY', 'CITY', 'nvarchar(100)', 'NULL', nil],
      ['STATE', 'STATE', 'nvarchar(2)', 'NULL', nil],
      ['ZIP_CODE', 'ZIP_CODE', 'nvarchar(10)', 'NULL', nil],
      ['LAST_LINE', 'LAST_LINE', 'nvarchar(110)', 'NULL', nil],
      ['USER_DEFINED_1', 'USER_DEFINED_1', 'nvarchar(100)', 'NULL', nil],
      ['USER_DEFINED_2', 'USER_DEFINED_2', 'nvarchar(100)', 'NULL', nil],
      ['USER_DEFINED_3', 'USER_DEFINED_3', 'nvarchar(100)', 'NULL', nil],
      ['USER_DEFINED_4', 'USER_DEFINED_4', 'nvarchar(100)', 'NULL', nil],
      ['USER_DEFINED_5', 'USER_DEFINED_5', 'nvarchar(100)', 'NULL', nil],
      ['USER_DEFINED_6', 'USER_DEFINED_6', 'nvarchar(100)', 'NULL', nil],
      ['USER_DEFINED_7', 'USER_DEFINED_7', 'nvarchar(100)', 'NULL', nil],
      ['USER_DEFINED_8', 'USER_DEFINED_8', 'nvarchar(100)', 'NULL', nil],
      ['USER_DEFINED_9', 'USER_DEFINED_9', 'nvarchar(100)', 'NULL', nil],
      ['USER_DEFINED_10', 'USER_DEFINED_10', 'nvarchar(100)', 'NULL', nil],
      ['USER_DEFINED_11', 'USER_DEFINED_11', 'nvarchar(100)', 'NULL', nil],
      ['USER_DEFINED_12', 'USER_DEFINED_12', 'nvarchar(100)', 'NULL', nil],
      ['USER_DEFINED_13', 'USER_DEFINED_13', 'nvarchar(100)', 'NULL', nil],
      ['USER_DEFINED_14', 'USER_DEFINED_14', 'nvarchar(100)', 'NULL', nil],
      ['USER_DEFINED_15', 'USER_DEFINED_15', 'nvarchar(100)', 'NULL', nil],
      ['MATCH_FLAG', 'MATCH_FLAG', 'nvarchar(100)', 'NULL', nil],
      ['MOVE_FOOTNOTE', 'MOVE_FOOTNOTE', 'nvarchar(100)', 'NULL', nil],
      ['MOVE_FOOTNOTE_LONG_DESCRIPTION', 'MOVE_FOOTNOTE_LONG_DESCRIPTION', 'nvarchar(200)', 'NULL', nil],
      ['ERROR_CODE', 'ERROR_CODE', 'nvarchar(100)', 'NULL', nil],
      ['ERROR_STRING', 'ERROR_STRING', 'nvarchar(200)', 'NULL', nil],
      ['DPC', 'DPC', 'int', 'NULL', nil],
      ['LOT_NUMBER', 'LOT_NUMBER', 'nvarchar(100)', 'NULL', nil],
      ['COUNTY_CODE', 'COUNTY_CODE', 'int', 'NULL', nil],
      ['COUNTY_NAME', 'COUNTY_NAME', 'nvarchar(100)', 'NULL', nil],
      ['SourceFileName', 'SourceFileName', 'nvarchar(max)', 'NULL', nil],
      ['ImportDateTime', 'ImportDateTime', 'datetime2(0)', 'NULL', nil],
      ['ID', 'ID', 'int', 'IDENTITY(0,1) NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'MoveResults',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
