# frozen_string_literal: true

[
  'Gsap2m_jobrefpurge',
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
      table: 'JobRefPurge',
      local: 'gsap2m_jobrefpurge.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['Job ID', 'Job ID', 'float', 'NULL', nil],
      ['OMS Document Profile', 'OMS Document Profile', 'nvarchar(255)', 'NULL', nil],
      ['OMS Communication Profile', 'OMS Communication Profile', 'nvarchar(255)', 'NULL', nil],
      ['OMS Production Workflow', 'OMS Production Workflow', 'nvarchar(255)', 'NULL', nil],
      ['Job Description', 'Job Description', 'nvarchar(255)', 'NULL', nil],
      ['AcctID', 'AcctID', 'nvarchar(255)', 'NULL', nil],
      ['Batchfile', 'Batchfile', 'nvarchar(255)', 'NULL', nil],
      ['Graphic Unit Cost', 'Graphic Unit Cost', 'float', 'NULL', nil],
      ['Full Postage Rate', 'Full Postage Rate', 'float', 'NULL', nil],
      ['Active', 'Active', 'bit', 'NOT NULL', nil],
      ['Agency', 'Agency', 'nvarchar(255)', 'NULL', nil],
      ['Department', 'Department', 'nvarchar(255)', 'NULL', nil],
      ['Budget Unit', 'Budget Unit', 'float', 'NULL', nil],
      ['Activity', 'Activity', 'nvarchar(255)', 'NULL', nil],
      ['Function', 'Function', 'nvarchar(255)', 'NULL', nil],
      ['Object', 'Object', 'float', 'NULL', nil],
      ['Program', 'Program', 'nvarchar(255)', 'NULL', nil],
      ['Phase', 'Phase', 'nvarchar(255)', 'NULL', nil],
      ['Task', 'Task', 'nvarchar(255)', 'NULL', nil],
      ['Program1', 'Program1', 'nvarchar(255)', 'NULL', nil],
      ['Service Account', 'Service Account', 'float', 'NULL', nil],
      ['Service Revenue Program', 'Service Revenue Program', 'nvarchar(255)', 'NULL', nil],
      ['Service Revenue Object', 'Service Revenue Object', 'float', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'JobRefPurge',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
