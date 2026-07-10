# frozen_string_literal: true

[
  'BuildingData',
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
      name: 'paperboy'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/building_data.xlsx',
      local: 'building_data.xlsx',
      format: :xlsx,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      [ nil,                                 'id',                   'bigint',        'IDENTITY(1,1) NOT NULL', nil ],
      [ 'building_code',                     'building_code',        'nvarchar(10)',  'NOT NULL',               nil ],
      [ 'building_description',              'building_description', 'nvarchar(100)', 'NULL',                   nil ],
      [ 'occupant_description',              'occupant_description', 'nvarchar(50)',  'NULL',                   nil ],
      [ 'site_description',                  'site_description',     'nvarchar(50)',  'NULL',                   nil ],
      [ 'site_type',                         'site_type',            'nvarchar(50)',  'NULL',                   nil ],
      [ 'campus',                            'campus',               'nvarchar(50)',  'NULL',                   nil ],
      [ 'gross_area',                        'gross_area',           'decimal(12,2)', 'NULL',                   nil ],
      [ 'pending_deletion',                  'pending_deletion',     'bit',           'NOT NULL',               nil ],
      [ 'bldg_own',                          'bldg_own',             'bit',           'NOT NULL',               nil ],
      [ 'bldg_lease',                        'bldg_lease',           'bit ',          'NOT NULL',               nil ],
      [ 'ownership',                         'ownership',            'nvarchar(10)',  'NULL',                   nil ],
      [ 'lease_type',                        'lease_type',           'nvarchar(10)',  'NULL',                   nil ],
      [ 'address',                           'address',              'nvarchar(100)', 'NULL',                   nil ],
      [ 'city',                              'city',                 'nvarchar(50)',  'NULL',                   nil ],
      [ 'zippostal_code',                    'zippostal_code',       'nvarchar(10)',  'NULL',                   nil ],
      [ 'inventory_code',                    'inventory_code',       'nvarchar(10)',  'NULL',                   nil ],
      [ 'number_of_floors',                  'number_of_floors',     'int',           'NULL',                   nil ],
      [ 'activeinactive',                    'activeinactive',       'nvarchar(10)',  'NULL',                   nil ],
      [ 'in_engie',                          'in_engie',             'bit',           'NOT NULL',               nil ],
      [ 'in_maintstar',                      'in_maintstar',         'bit',           'NOT NULL',               nil ]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'building_data',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
