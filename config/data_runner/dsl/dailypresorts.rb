# frozen_string_literal: true

[
  'Dailypresorts',
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
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/00_Inbox/dailypresort.csv',
      local: 'dailypresorts.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      [nil,                    'id',                   'int',           'IDENTITY(0,1) NOT NULL', nil],
      ['omsnumber',            'omsnumber',            'int',           'NULL',                   nil],
      ['fld_record_id',        'fldrecordid',          'int',           'NULL',                   nil],
      ['fld_business',         'fldbusiness',          'nvarchar(200)', 'NULL',                   nil],
      ['fld_first_name',       'fldfirstname',         'nvarchar(200)', 'NULL',                   nil],
      ['fld_last_name',        'fldlastname',          'nvarchar(200)', 'NULL',                   nil],
      ['fld_addressline1',     'fldaddressline1',      'nvarchar(200)', 'NULL',                   nil],
      ['fld_addressline2',     'fldaddressline2',      'nvarchar(200)', 'NULL',                   nil],
      ['fld_lastline',         'fldlastline',          'nvarchar(200)', 'NULL',                   nil],
      ['fld_city',             'fldcity',              'nvarchar(200)', 'NULL',                   nil],
      ['fld_state',            'fldstate',             'nvarchar(2)',   'NULL',                   nil],
      ['fld_zipcode',          'fldzipcode',           'nvarchar(200)', 'NULL',                   nil],
      ['fld_presort_id',       'fldpresortid',         'int',           'NULL',                   nil],
      ['fld_break_mark',       'fldbreakmark',         'nvarchar(200)', 'NULL',                   nil],
      ['fld_keyline',          'fldkeyline',           'nvarchar(200)', 'NULL',                   nil],
      ['fld_endorsement_line', 'fldendorsementline',   'nvarchar(200)', 'NULL',                   nil],
      ['fld_im_barcode',       'fldimbarcode',         'nvarchar(200)', 'NULL',                   nil],
      ['fld_user_defined_1',   'flduserdefined1',      'nvarchar(200)', 'NULL',                   nil],
      ['fld_user_defined_2',   'flduserdefined2',      'nvarchar(200)', 'NULL',                   nil],
      ['fld_user_defined_3',   'flduserdefined3',      'nvarchar(200)', 'NULL',                   nil],
      ['fld_user_defined_4',   'flduserdefined4',      'nvarchar(200)', 'NULL',                   nil],
      ['fld_user_defined_5',   'flduserdefined5',      'nvarchar(200)', 'NULL',                   nil],
      ['fld_user_defined_6',   'flduserdefined6',      'nvarchar(200)', 'NULL',                   nil],
      ['fld_user_defined_7',   'flduserdefined7',      'nvarchar(200)', 'NULL',                   nil],
      ['fld_user_defined_8',   'flduserdefined8',      'nvarchar(200)', 'NULL',                   nil],
      ['fld_user_defined_9',   'flduserdefined9',      'nvarchar(200)', 'NULL',                   nil],
      ['fld_user_defined_10',  'flduserdefined10',     'nvarchar(200)', 'NULL',                   nil],
      ['fld_user_defined_11',  'flduserdefined11',     'nvarchar(200)', 'NULL',                   nil],
      ['fld_user_defined_12',  'flduserdefined12',     'nvarchar(200)', 'NULL',                   nil],
      ['fld_user_defined_13',  'flduserdefined13',     'nvarchar(200)', 'NULL',                   nil],
      ['fld_user_defined_14',  'flduserdefined14',     'nvarchar(200)', 'NULL',                   nil],
      ['fld_user_defined_15',  'flduserdefined15',     'nvarchar(200)', 'NULL',                   nil],
      ['fld_im_piece_identifier', 'fldimpieceidentifier', 'nvarchar(200)', 'NULL',                nil],
      ['fld_piece_postage',    'fldpiecepostage',      'numeric(5,3)',  'NULL',                   nil],
      ['fld_piece_weight',     'fldpieceweight',       'numeric(7,4)',  'NULL',                   nil],
      ['fld_piece_thickness',  'fldpiecethickness',    'numeric(7,4)',  'NULL',                   nil],
      ['fld_piece_length',     'fldpiecelength',       'numeric(7,4)',  'NULL',                   nil],
      ['fld_piece_height',     'fldpieceheight',       'numeric(7,4)',  'NULL',                   nil],
      ['fld_package_number',   'fldpackagenumber',     'int',           'NULL',                   nil],
      ['fld_tray_number',      'fldtraynumber',        'int',           'NULL',                   nil],
      ['fld_pallet_number',    'fldpalletnumber',      'int',           'NULL',                   nil],
      [nil,                    'sourcefilename',       'nvarchar(max)', 'NULL',                   nil],
      ['importdatetime',       'importdatetime',       'datetime2(0)',  'NULL',                   nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'daily_presorts',
        inject: {
          mode: :append,
          reject_existing: %w[omsnumber]
        }
      }
    ]
  }
]
