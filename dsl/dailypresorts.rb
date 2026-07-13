# frozen_string_literal: true

[
  'Dailypresorts',
  {
    steps: {
      enabled: true,
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
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/dailypresort.csv',
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

      [nil,                    'id',              'bigint',        'IDENTITY(0,1) NOT NULL', nil],
      ['omsnumber',            'oms_number',      'int',           'NULL',                   nil],
      ['FldRecordID',          nil,               'int',           'NULL',                   nil],
      ['FldBusiness',          nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldFirstName',         nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldLastName',          nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldAddressLine1',      nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldAddressLine2',      nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldLastline',          nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldCity',              nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldState',             nil,               'nvarchar(2)',   'NULL',                   nil],
      ['FldZipcode',           nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldPresortId',         nil,               'int',           'NULL',                   nil],
      ['FldBreakMark',         nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldKeyline',           nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldEndorsementLine',   nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldIMBarcode',         nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldUserDefined1',      nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldUserDefined2',      nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldUserDefined3',      nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldUserDefined4',      nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldUserDefined5',      nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldUserDefined6',      nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldUserDefined7',      nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldUserDefined8',      nil,               'nvarchar(200)', 'NULL',                   nil],
      ['flduserdefined9',      'job_id',          'nvarchar(200)', 'NULL',                   nil],
      ['FldUserDefined10',     nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldUserDefined11',     nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldUserDefined12',     nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldUserDefined13',     nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldUserDefined14',     nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldUserDefined15',     nil,               'nvarchar(200)', 'NULL',                   nil],
      ['FldIMPieceIdentifier', nil,               'nvarchar(200)', 'NULL',                   nil],
      ['fldpiecepostage',      'postage',         'numeric(5,3)',  'NULL',                   nil],
      ['FldPieceWeight',       nil,               'numeric(7,4)',  'NULL',                   nil],
      ['FldPieceThickness',    nil,               'numeric(7,4)',  'NULL',                   nil],
      ['FldPieceLength',       nil,               'numeric(7,4)',  'NULL',                   nil],
      ['FldPieceHeight',       nil,               'numeric(7,4)',  'NULL',                   nil],
      ['FldPackageNumber',     nil,               'int',           'NULL',                   nil],
      ['FldTrayNumber',        nil,               'int',           'NULL',                   nil],
      ['FldPalletNumber',      nil,               'int',           'NULL',                   nil],
      ['SourceFileName',       nil,               'nvarchar(max)', 'NULL',                   nil],
      ['importdatetime',       'import_date_time', 'datetime2(0)', 'NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'daily_presorts',
        inject: {
          mode: :append
        }
      }
    ]
  }
]
