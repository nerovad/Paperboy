# frozen_string_literal: true

[
  'Document Automation',
  {
    steps: {
      manual: {
        enabled: true,
        steps: Workflow::MANUAL_STEPS
      },
      scheduled: {
        enabled: false,
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'billing'
    },
    sop: {
      title: 'How to Download Document Automation',
      source_system: 'Document Automation',
      reference_title: 'Document Automation File',
      reference_path: :source_location,
      instructions: [
        'The Microsoft Excel document is updated annually or when pricing changes.',
        'Verify document_automation.xlsx is current.'
      ]
    },
    source: {
      location: File.join(ENV.fetch('DATARUNNER_INBOX'), 'document_automation.xlsx'),
      local: 'document_automation.xlsx',
      format: :xlsx,
      strategy: :copy
    },
    output: 'document_automation.csv',
    to_csv: {
      sheet: 0,
      header_row: 0,
      data_row: 1
    },
    header: [

      ['type',        'type',        'nvarchar(3)',   'NULL', nil],
      ['cunit',       'cunit',       'nvarchar(4)',   'NULL', nil],
      ['cobject',     'cobject',     'nvarchar(4)',   'NULL', nil],
      ['cactivity',   'cactivity',   'nvarchar(4)',   'NULL', nil],
      ['cfunction',   'cfunction',   'nvarchar(4)',   'NULL', nil],
      ['cprogram',    'cprogram',    'nvarchar(10)',  'NULL', nil],
      ['cphase',      'cphase',      'nvarchar(6)',   'NULL', nil],
      ['ctask',       'ctask',       'nvarchar(4)',   'NULL', nil],
      ['amount',      'amount',      'float',         'NULL', '((0.0))'],
      ['sunit',       'sunit',       'nvarchar(4)',   'NULL', nil],
      ['sobject',     'sobject',     'nvarchar(4)',   'NULL', nil],
      ['sactivity',   'sactivity',   'nvarchar(4)',   'NULL', nil],
      ['sfunction',   'sfunction',   'nvarchar(4)',   'NULL', nil],
      ['sprogram',    'sprogram',    'nvarchar(10)',  'NULL', nil],
      ['sphase',      'sphase',      'nvarchar(6)',   'NULL', nil],
      ['stask',       'stask',       'nvarchar(4)',   'NULL', nil],
      ['posting_ref', 'posting_ref', 'nvarchar(20)',  'NULL', nil],
      ['service',     'service',     'nvarchar(15)',  'NULL', nil],
      ['date',        'date',        'date',          'NULL', nil],
      ['doc_nmbr',    'doc_nmbr',    'nvarchar(50)',  'NULL', nil],
      ['description', 'description', 'nvarchar(100)', 'NULL', nil],
      ['other1',      'other1',      'nvarchar(50)',  'NULL', nil],
      ['other2',      'other2',      'nvarchar(50)',  'NULL', nil],
      ['other3',      'other3',      'nvarchar(50)',  'NULL', nil],
      ['quantity',    'quantity',    'float',         'NULL', '((0.0))'],
      ['rate',        'rate',        'float',         'NULL', '((0.0))'],
      ['cost',        'cost',        'float',         'NULL', '((0.0))']

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSA Scan',
        schema: 'dbo',
        table: 'document_automation',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
