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
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/00_Inbox/moveresults.csv',
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

      ['omsnumber',                      'omsnumber',                      'int',           'NULL',                   nil],
      ['record_id',                      'record_id',                      'int',           'NULL',                   nil],
      ['business',                       'business',                       'nvarchar(100)', 'NULL',                   nil],
      ['first_name',                     'first_name',                     'nvarchar(100)', 'NULL',                   nil],
      ['last_name',                      'last_name',                      'nvarchar(150)', 'NULL',                   nil],
      ['address_line_1',                 'address_line_1',                 'nvarchar(100)', 'NULL',                   nil],
      ['address_line_2',                 'address_line_2',                 'nvarchar(100)', 'NULL',                   nil],
      ['city',                           'city',                           'nvarchar(100)', 'NULL',                   nil],
      ['state',                          'state',                          'nvarchar(2)',   'NULL',                   nil],
      ['zip_code',                       'zip_code',                       'nvarchar(10)',  'NULL',                   nil],
      ['last_line',                      'last_line',                      'nvarchar(110)', 'NULL',                   nil],
      ['user_defined_1',                 'user_defined_1',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_2',                 'user_defined_2',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_3',                 'user_defined_3',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_4',                 'user_defined_4',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_5',                 'user_defined_5',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_6',                 'user_defined_6',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_7',                 'user_defined_7',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_8',                 'user_defined_8',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_9',                 'user_defined_9',                 'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_10',                'user_defined_10',                'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_11',                'user_defined_11',                'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_12',                'user_defined_12',                'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_13',                'user_defined_13',                'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_14',                'user_defined_14',                'nvarchar(100)', 'NULL',                   nil],
      ['user_defined_15',                'user_defined_15',                'nvarchar(100)', 'NULL',                   nil],
      ['match_flag',                     'match_flag',                     'nvarchar(100)', 'NULL',                   nil],
      ['move_footnote',                  'move_footnote',                  'nvarchar(100)', 'NULL',                   nil],
      ['move_footnote_long_description', 'move_footnote_long_description', 'nvarchar(200)', 'NULL',                   nil],
      ['error_code',                     'error_code',                     'nvarchar(100)', 'NULL',                   nil],
      ['error_string',                   'error_string',                   'nvarchar(200)', 'NULL',                   nil],
      ['dpc',                            'dpc',                            'int',           'NULL',                   nil],
      ['lot_number',                     'lot_number',                     'nvarchar(100)', 'NULL',                   nil],
      ['county_code',                    'county_code',                    'int',           'NULL',                   nil],
      ['county_name',                    'county_name',                    'nvarchar(100)', 'NULL',                   nil],
      [nil,                              'sourcefilename',                 'nvarchar(max)', 'NULL',                   nil],
      ['importdatetime',                 'importdatetime',                 'datetime2(0)',  'NULL',                   nil],
      [nil,                              'id',                             'int',           'IDENTITY(0,1) NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'move_results',
        inject: {
          mode: :append
        }
      }
    ]
  }
]
