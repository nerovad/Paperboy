# frozen_string_literal: true

[
  'Gsap2m_p2mjobs',
  {
     steps: {
      manual: {
        enabled: true,
        steps: Workflow::MANUAL_STEPS
      },
      scheduled: {
        enabled: true,
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'gsap2m'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSAP2M',
      schema: 'dbo',
      table: 'P2MJobs',
      local: 'gsap2m_p2mjobs.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['FYEAR', 'FYEAR', 'nvarchar(50)', 'NOT NULL', nil],
      ['Job_ID', 'Job_ID', 'nvarchar(50)', 'NOT NULL', nil],
      ['OMS_Document_Profile', 'OMS_Document_Profile', 'nvarchar(100)', 'NOT NULL', nil],
      ['OMS_Communication_Profile', 'OMS_Communication_Profile', 'nvarchar(50)', 'NOT NULL', nil],
      ['OMS_Production_Workflow', 'OMS_Production_Workflow', 'nvarchar(50)', 'NOT NULL', nil],
      ['Media_Channel', 'Media_Channel', 'nvarchar(50)', 'NOT NULL', nil],
      ['Job_Description', 'Job_Description', 'nvarchar(100)', 'NOT NULL', nil],
      ['Graphic_Unit_Cost', 'Graphic_Unit_Cost', 'float', 'NOT NULL', nil],
      ['P2MUnitCost', 'P2MUnitCost', 'float', 'NOT NULL', nil],
      ['Full_Postage_Rate', 'Full_Postage_Rate', 'float', 'NOT NULL', nil],
      ['Active', 'Active', 'smallint', 'NOT NULL', nil],
      ['Agency', 'Agency', 'nvarchar(50)', 'NOT NULL', nil],
      ['Department', 'Department', 'nvarchar(50)', 'NOT NULL', nil],
      ['Budget_Unit', 'Budget_Unit', 'nvarchar(4)', 'NOT NULL', nil],
      ['Object', 'Object', 'nvarchar(4)', 'NOT NULL', nil],
      ['Activity', 'Activity', 'nvarchar(4)', 'NOT NULL', nil],
      ['Function', 'Function', 'nvarchar(4)', 'NOT NULL', nil],
      ['CPROJ', 'CPROJ', 'nvarchar(10)', 'NULL', nil],
      ['Program', 'Program', 'nvarchar(10)', 'NULL', nil],
      ['Phase', 'Phase', 'nvarchar(6)', 'NULL', nil],
      ['Task', 'Task', 'nvarchar(4)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'P2MJobs',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
