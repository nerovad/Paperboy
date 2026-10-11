# frozen_string_literal: true

[
  'Gsap2m_dailypresort',
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
      name: 'gsap2m'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSAP2M',
      schema: 'dbo',
      table: 'DailyPresort',
      local: 'gsap2m_dailypresort.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'int', 'IDENTITY(0,1) NOT NULL', nil],
      ['omsnumber', 'omsnumber', 'int', 'NULL', nil],
      ['fldrecordid', 'fldrecordid', 'int', 'NULL', nil],
      ['fldbusiness', 'fldbusiness', 'nvarchar(200)', 'NULL', nil],
      ['fldfirstname', 'fldfirstname', 'nvarchar(200)', 'NULL', nil],
      ['fldlastname', 'fldlastname', 'nvarchar(200)', 'NULL', nil],
      ['fldaddressline1', 'fldaddressline1', 'nvarchar(200)', 'NULL', nil],
      ['fldaddressline2', 'fldaddressline2', 'nvarchar(200)', 'NULL', nil],
      ['fldlastline', 'fldlastline', 'nvarchar(200)', 'NULL', nil],
      ['fldcity', 'fldcity', 'nvarchar(200)', 'NULL', nil],
      ['fldstate', 'fldstate', 'nvarchar(2)', 'NULL', nil],
      ['fldzipcode', 'fldzipcode', 'nvarchar(200)', 'NULL', nil],
      ['fldpresortid', 'fldpresortid', 'int', 'NULL', nil],
      ['fldbreakmark', 'fldbreakmark', 'nvarchar(200)', 'NULL', nil],
      ['fldkeyline', 'fldkeyline', 'nvarchar(200)', 'NULL', nil],
      ['fldendorsementline', 'fldendorsementline', 'nvarchar(200)', 'NULL', nil],
      ['fldimbarcode', 'fldimbarcode', 'nvarchar(200)', 'NULL', nil],
      ['flduserdefined1', 'flduserdefined1', 'nvarchar(200)', 'NULL', nil],
      ['flduserdefined2', 'flduserdefined2', 'nvarchar(200)', 'NULL', nil],
      ['flduserdefined3', 'flduserdefined3', 'nvarchar(200)', 'NULL', nil],
      ['flduserdefined4', 'flduserdefined4', 'nvarchar(200)', 'NULL', nil],
      ['flduserdefined5', 'flduserdefined5', 'nvarchar(200)', 'NULL', nil],
      ['flduserdefined6', 'flduserdefined6', 'nvarchar(200)', 'NULL', nil],
      ['flduserdefined7', 'flduserdefined7', 'nvarchar(200)', 'NULL', nil],
      ['flduserdefined8', 'flduserdefined8', 'nvarchar(200)', 'NULL', nil],
      ['flduserdefined9', 'flduserdefined9', 'nvarchar(200)', 'NULL', nil],
      ['flduserdefined10', 'flduserdefined10', 'nvarchar(200)', 'NULL', nil],
      ['flduserdefined11', 'flduserdefined11', 'nvarchar(200)', 'NULL', nil],
      ['flduserdefined12', 'flduserdefined12', 'nvarchar(200)', 'NULL', nil],
      ['flduserdefined13', 'flduserdefined13', 'nvarchar(200)', 'NULL', nil],
      ['flduserdefined14', 'flduserdefined14', 'nvarchar(200)', 'NULL', nil],
      ['flduserdefined15', 'flduserdefined15', 'nvarchar(200)', 'NULL', nil],
      ['fldimpieceidentifier', 'fldimpieceidentifier', 'nvarchar(200)', 'NULL', nil],
      ['fldpiecepostage', 'fldpiecepostage', 'numeric(5,3)', 'NULL', nil],
      ['fldpieceweight', 'fldpieceweight', 'numeric(7,4)', 'NULL', nil],
      ['fldpiecethickness', 'fldpiecethickness', 'numeric(7,4)', 'NULL', nil],
      ['fldpiecelength', 'fldpiecelength', 'numeric(7,4)', 'NULL', nil],
      ['fldpieceheight', 'fldpieceheight', 'numeric(7,4)', 'NULL', nil],
      ['fldpackagenumber', 'fldpackagenumber', 'int', 'NULL', nil],
      ['fldtraynumber', 'fldtraynumber', 'int', 'NULL', nil],
      ['fldpalletnumber', 'fldpalletnumber', 'int', 'NULL', nil],
      ['sourcefilename', 'sourcefilename', 'nvarchar(max)', 'NULL', nil],
      ['importdatetime', 'importdatetime', 'datetime2(0)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'DailyPresort',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
