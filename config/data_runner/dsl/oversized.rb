# frozen_string_literal: true

[
  'Oversized',
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
      name: 'billing'
    },
    sop: {
      title: 'How to Download Oversized Scan Data',
      source_system: 'Oversized Scanners',
      reference_title: 'Scanner Export Folder',
      reference_path: '/mnt/i/BUSINESS_SUPPORT/Scan Center/Oversized Scan Data/Monthly Exports',
      instructions: [
        'Open the Monthly Exports folder.',
        'Confirm ovs-1.xml was exported from Context IQ Quattro.',
        'Confirm ovs-2.xml was exported from Context HD Ultra.',
        'Examine the folder contents and verify both files are current.'
      ]
    },
    source: {
      location: nil,
      local: 'oversized.csv',
      format: :csv,
      strategy: :script,
      script: {
        path: 'script/ruby/data_runner/download/oversized.rb',
        args: ['ALL']
      }
    },
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['date',        'date',        'date',          'NULL', nil],
      ['profiletype', 'profiletype', 'nvarchar(max)', 'NULL', nil],
      ['bu',          'bu',          'int',           'NULL', nil],
      ['length',      'length',      'float',         'NULL', '((0.0))'],
      ['width',       'width',       'float',         'NULL', '((0.0))'],
      ['type',        'type',        'nvarchar(max)', 'NULL', nil],
      ['filepath',    'filepath',    'nvarchar(max)', 'NULL', nil],
      ['filename',    'filename',    'nvarchar(max)', 'NULL', nil]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSA Scan',
        schema: 'dbo',
        table: '_stgOversized_Scan_Data',
        inject: {
          mode: :truncate_insert,
          post_script: {
            path: 'script/ruby/data_runner/inject/oversized.rb'
          }
        }
      }
    ]
  }
]
