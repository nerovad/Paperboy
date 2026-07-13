# frozen_string_literal: true

[
  'CameraHardware',
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
      name: 'gsa_security'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/camera_hardware.xlsx',
      local: 'camera_hardware.xlsx',
      format: :xlsx,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 6,
      data_row: 7
    },
    header: [

      ['unit_type',                'unit_type',        'nvarchar(10)',  'NOT NULL', nil],
      ['state',                    'state',            'nvarchar(10)',  'NOT NULL', nil],
      ['budget_number_video_unit', 'budget_unit_id',   'nvarchar(4)',   'NOT NULL', nil],
      ['unit',                     'camera_location',  'nvarchar(100)', 'NOT NULL', nil],
      ['address_video_unit',       'camera_address',   'nvarchar(100)', 'NOT NULL', nil],
      ['agency_video_unit',        'agency_id',        'nvarchar(5)',   'NULL',     nil],
      ['doc_number_video_unit',    'doc_number',       'nvarchar(50)',  'NULL',     nil],
      ['manufacturer',             'manufacturer',     'nvarchar(50)',  'NOT NULL', nil],
      ['product_type',             'product_type',     'nvarchar(50)',  'NOT NULL', nil],
      ['role',                     'role',             'nvarchar(50)',  'NOT NULL', nil],
      ['ip_address',               'ip_address',       'nvarchar(15)',  'NOT NULL', nil],
      ['physical_address',         'physical_address', 'nvarchar(17)',  'NOT NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'camera_hardware',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
