# frozen_string_literal: true

[
  'Gsabss_ad_orgchart',
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
      name: 'gsabss'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSABSS',
      schema: 'dbo',
      table: 'ad_orgchart',
      local: 'gsabss_ad_orgchart.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['displayname', 'displayname', 'nvarchar(max)', 'NULL', nil],
      ['givenname', 'givenname', 'nvarchar(max)', 'NULL', nil],
      ['surname', 'surname', 'nvarchar(max)', 'NULL', nil],
      ['title', 'title', 'nvarchar(max)', 'NULL', nil],
      ['company', 'company', 'nvarchar(max)', 'NULL', nil],
      ['department', 'department', 'nvarchar(max)', 'NULL', nil],
      ['division', 'division', 'nvarchar(max)', 'NULL', nil],
      ['office', 'office', 'nvarchar(max)', 'NULL', nil],
      ['physicaloffice', 'physicaloffice', 'nvarchar(max)', 'NULL', nil],
      ['emailaddress', 'emailaddress', 'nvarchar(max)', 'NULL', nil],
      ['userprincipalname', 'userprincipalname', 'nvarchar(max)', 'NULL', nil],
      ['samaccountname', 'samaccountname', 'nvarchar(max)', 'NULL', nil],
      ['employeeid', 'employeeid', 'nvarchar(max)', 'NULL', nil],
      ['employeenumber', 'employeenumber', 'nvarchar(max)', 'NULL', nil],
      ['managername', 'managername', 'nvarchar(max)', 'NULL', nil],
      ['managertitle', 'managertitle', 'nvarchar(max)', 'NULL', nil],
      ['manageremail', 'manageremail', 'nvarchar(max)', 'NULL', nil],
      ['managerdn', 'managerdn', 'nvarchar(max)', 'NULL', nil],
      ['directreports', 'directreports', 'nvarchar(max)', 'NULL', nil],
      ['enabled', 'enabled', 'nvarchar(max)', 'NULL', nil],
      ['oupath', 'oupath', 'nvarchar(max)', 'NULL', nil],
      ['distinguishedname', 'distinguishedname', 'nvarchar(max)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'ad_orgchart',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
