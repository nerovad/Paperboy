# frozen_string_literal: true

[
  'Moveresults',
  {
    steps: {
      enabled: false,
      manual_steps: Workflow::MANUAL_STEPS,
      scheduled: {
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'print_2_mail_billing_data'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/moveresults.csv',
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

      ['omsnumber',                      'oms_number',         'int',           'NULL',                   nil],
      ['record_id',                      'record_id',          'int',           'NULL',                   nil],
      ['business',                       'business',           'nvarchar(100)', 'NULL',                   nil],
      ['first_name',                     'first_name',         'nvarchar(100)', 'NULL',                   nil],
      ['last_name',                      'last_name',          'nvarchar(150)', 'NULL',                   nil],
      ['address_line_1',                 'address_line_1',     'nvarchar(max)', 'NULL',                   nil],
      ['address_line_2',                 'address_line_2',     'nvarchar(max)', 'NULL',                   nil],
      ['city',                           'city',               'nvarchar(100)', 'NULL',                   nil],
      ['state',                          'state',              'nvarchar(2)',   'NULL',                   nil],
      ['zip_code',                       'zip_code',           'nvarchar(10)',  'NULL',                   nil],
      ['LAST_LINE',                      nil,                  'nvarchar(110)', 'NULL',                   nil],
      ['USER_DEFINED_1',                 nil,                  'nvarchar(100)', 'NULL',                   nil],
      ['USER_DEFINED_2',                 nil,                  'nvarchar(100)', 'NULL',                   nil],
      ['USER_DEFINED_3',                 nil,                  'nvarchar(100)', 'NULL',                   nil],
      ['USER_DEFINED_4',                 nil,                  'nvarchar(100)', 'NULL',                   nil],
      ['USER_DEFINED_5',                 nil,                  'nvarchar(100)', 'NULL',                   nil],
      ['USER_DEFINED_6',                 nil,                  'nvarchar(100)', 'NULL',                   nil],
      ['USER_DEFINED_7',                 nil,                  'nvarchar(100)', 'NULL',                   nil],
      ['USER_DEFINED_8',                 nil,                  'nvarchar(100)', 'NULL',                   nil],
      ['USER_DEFINED_9',                 nil,                  'nvarchar(100)', 'NULL',                   nil],
      ['USER_DEFINED_10',                nil,                  'nvarchar(100)', 'NULL',                   nil],
      ['USER_DEFINED_11',                nil,                  'nvarchar(100)', 'NULL',                   nil],
      ['USER_DEFINED_12',                nil,                  'nvarchar(100)', 'NULL',                   nil],
      ['USER_DEFINED_13',                nil,                  'nvarchar(100)', 'NULL',                   nil],
      ['USER_DEFINED_14',                nil,                  'nvarchar(100)', 'NULL',                   nil],
      ['USER_DEFINED_15',                nil,                  'nvarchar(100)', 'NULL',                   nil],
      ['match_flag',                     'match_flag',         'nvarchar(100)', 'NULL',                   nil],
      ['move_footnote',                  'move_footnote',      'nvarchar(100)', 'NULL',                   nil],
      ['move_footnote_long_description', 'move_footnote_desc', 'nvarchar(200)', 'NULL',                   nil],
      ['error_code',                     'error_code',         'nvarchar(100)', 'NULL',                   nil],
      ['error_string',                   'error_string',       'nvarchar(200)', 'NULL',                   nil],
      ['dpc',                            'dpc',                'int',           'NULL',                   nil],
      ['lot_number',                     'lot_number',         'nvarchar(100)', 'NULL',                   nil],
      ['county_code',                    'county_code',        'int',           'NULL',                   nil],
      ['county_name',                    'county_name',        'nvarchar(100)', 'NULL',                   nil],
      ['SourceFileName',                 nil,                  'nvarchar(max)', 'NULL',                   nil],
      ['importdatetime',                 'import_date_time',   'datetime2(0)',  'NULL',                   nil],
      [nil,                              'id',                 'int',           'IDENTITY(0,1) NOT NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'mover_esults',
        inject: {
          mode: :append
        }
      }
    ]
  }
]
