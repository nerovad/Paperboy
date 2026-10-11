# frozen_string_literal: true

[
  'Paperboy_dev_osha_establishments',
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
      name: 'paperboy_dev'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'osha_establishments',
      local: 'paperboy_dev_osha_establishments.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['name', 'name', 'nvarchar(100)', 'NOT NULL', nil],
      ['ein', 'ein', 'nvarchar(9)', 'NOT NULL', nil],
      ['company_name', 'company_name', 'nvarchar(100)', 'NULL', nil],
      ['street_address', 'street_address', 'nvarchar(100)', 'NOT NULL', nil],
      ['city', 'city', 'nvarchar(100)', 'NOT NULL', nil],
      ['state', 'state', 'nvarchar(2)', 'NOT NULL', nil],
      ['zip', 'zip', 'nvarchar(9)', 'NOT NULL', nil],
      ['naics_code', 'naics_code', 'int', 'NOT NULL', nil],
      ['industry_description', 'industry_description', 'nvarchar(300)', 'NULL', nil],
      ['size', 'size', 'int', 'NOT NULL', nil],
      ['establishment_type', 'establishment_type', 'int', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'osha_establishments',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
