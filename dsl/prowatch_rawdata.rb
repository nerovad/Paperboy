# frozen_string_literal: true

[
  'ProwatchRawdata',
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
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/prowatch_rawdata.csv',
      local: 'prowatch_rawdata.csv',
      format: :csv,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['site',                     'site',                     'nvarchar(max)', 'NULL', nil],
      ['hw_class',                 'hw_class',                 'nvarchar(max)', 'NULL', nil],
      ['hw_template',              'hw_template',              'nvarchar(max)', 'NULL', nil],
      ['location',                 'location',                 'nvarchar(max)', 'NULL', nil],
      ['device',                   'device',                   'nvarchar(max)', 'NULL', nil],
      ['description_alt',          'description_alt',          'nvarchar(max)', 'NULL', nil],
      ['panel',                    'panel',                    'nvarchar(max)', 'NULL', nil],
      ['device_types',             'device_types',             'nvarchar(max)', 'NULL', nil],
      ['hw_description',           'hw_description',           'nvarchar(max)', 'NULL', nil],
      ['category',                 'category',                 'nvarchar(max)', 'NULL', nil],
      ['subcategory',              'subcategory',              'nvarchar(max)', 'NULL', nil],
      ['default_audio_file',       'default_audio_file',       'nvarchar(max)', 'NULL', nil],
      ['default_avi_file',         'default_avi_file',         'nvarchar(max)', 'NULL', nil],
      ['default_pager',            'default_pager',            'nvarchar(max)', 'NULL', nil],
      ['default_email',            'default_email',            'nvarchar(max)', 'NULL', nil],
      ['default_map',              'default_map',              'nvarchar(max)', 'NULL', nil],
      ['default_intercom',         'default_intercom',         'nvarchar(max)', 'NULL', nil],
      ['default_autocctv_view',    'default_autocctv_view',    'nvarchar(max)', 'NULL', nil],
      ['default_autocctv_cmd',     'default_autocctv_cmd',     'nvarchar(max)', 'NULL', nil],
      ['default_select_cctv_view', 'default_select_cctv_view', 'nvarchar(max)', 'NULL', nil],
      ['default_select_cctv_cmd',  'default_select_cctv_cmd',  'nvarchar(max)', 'NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'prowatch_rawdata',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
