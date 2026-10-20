# frozen_string_literal: true

[
  'Moveresults',
  {
    steps: {
      manual: {
        enabled: false,
        steps: Workflow::MANUAL_STEPS
      },
      scheduled: {
        enabled: true,
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'print_2_mail_billing_data'
    },
    source: {
      location: File.join(ENV.fetch('DATARUNNER_INBOX'), 'moveresults.csv'),
      local: 'moveresults.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['omsnumber', 'OMSNumber',                      'int',           'NULL',                   nil],
      ['record_id', 'RECORD_ID',                      'int',           'NULL',                   nil],
      ['business', 'BUSINESS',                       'nvarchar(100)', 'NULL',                   nil],
      ['first_name', 'FIRST_NAME',                     'nvarchar(100)', 'NULL',                   nil],
      ['last_name', 'LAST_NAME',                      'nvarchar(150)', 'NULL',                   nil],
      ['address_line_1', 'ADDRESS_LINE_1',                 'nvarchar(100)', 'NULL',                   nil],
      ['address_line_2', 'ADDRESS_LINE_2',                 'nvarchar(100)', 'NULL',                   nil],
      ['city', 'CITY',                           'nvarchar(100)', 'NULL',                   nil],
      ['state', 'STATE',                          'nvarchar(2)',   'NULL',                   nil],
      ['zip_code', 'ZIP_CODE',                       'nvarchar(10)',  'NULL',                   nil],
      ['last_line', 'LAST_LINE',                      'nvarchar(110)', 'NULL',                   nil],
      ['user_defined_1', 'USER_DEFINED_1',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_2', 'USER_DEFINED_2',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_3', 'USER_DEFINED_3',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_4', 'USER_DEFINED_4',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_5', 'USER_DEFINED_5',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_6', 'USER_DEFINED_6',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_7', 'USER_DEFINED_7',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_8', 'USER_DEFINED_8',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_9', 'USER_DEFINED_9',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_10', 'USER_DEFINED_10',                'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_11', 'USER_DEFINED_11',                'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_12', 'USER_DEFINED_12',                'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_13', 'USER_DEFINED_13',                'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_14', 'USER_DEFINED_14',                'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_15', 'USER_DEFINED_15',                'nvarchar(100)', 'NULL',                   nil],
      ['match_flag', 'MATCH_FLAG',                     'nvarchar(100)', 'NULL',                   nil],
      ['move_footnote', 'MOVE_FOOTNOTE',                  'nvarchar(100)', 'NULL',                   nil],
      ['move_footnote_long_description', 'MOVE_FOOTNOTE_LONG_DESCRIPTION', 'nvarchar(200)', 'NULL',                   nil],
      ['error_code', 'ERROR_CODE',                     'nvarchar(100)', 'NULL',                   nil],
      ['error_string', 'ERROR_STRING',                   'nvarchar(200)', 'NULL',                   nil],
      ['dpc', 'DPC',                            'int',           'NULL',                   nil],
      ['lot_number', 'LOT_NUMBER',                     'nvarchar(100)', 'NULL',                   nil],
      ['county_code', 'COUNTY_CODE',                    'int',           'NULL',                   nil],
      ['county_name', 'COUNTY_NAME',                    'nvarchar(100)', 'NULL',                   nil],
      [nil,                              'SourceFileName',                 'nvarchar(max)', 'NULL',                   nil],
      ['importdatetime', 'ImportDateTime',                 'datetime2(0)',  'NULL',                   nil],
      [nil,                              'ID',                             'int',           'IDENTITY(0,1) NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'GSASQL16.ent.co.ventura.ca.us',
        database: 'GSAP2M',
        schema: 'dbo',
        table: 'MoveResults',
        inject: {
          mode: :append,
          reject_existing: %w[OMSNumber]
        }
      }
    ]
  }
]
