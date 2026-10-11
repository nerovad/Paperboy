# frozen_string_literal: true

[
  'Gsabss_buildings',
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
      name: 'gsabss'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSABSS',
      schema: 'dbo',
      table: 'buildings',
      local: 'gsabss_buildings.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['building_code', 'building_code', 'nvarchar(10)', 'NOT NULL', nil],
      ['building_description', 'building_description', 'nvarchar(100)', 'NULL', nil],
      ['occupant_description', 'occupant_description', 'nvarchar(50)', 'NULL', nil],
      ['site_description', 'site_description', 'nvarchar(50)', 'NULL', nil],
      ['site_type', 'site_type', 'nvarchar(50)', 'NULL', nil],
      ['campus', 'campus', 'nvarchar(50)', 'NULL', nil],
      ['gross_area', 'gross_area', 'decimal(12,2)', 'NULL', nil],
      ['pending_deletion', 'pending_deletion', 'bit', 'NOT NULL', nil],
      ['bldg_own', 'bldg_own', 'bit', 'NOT NULL', nil],
      ['bldg_lease', 'bldg_lease', 'bit', 'NOT NULL', nil],
      ['ownership', 'ownership', 'nvarchar(10)', 'NULL', nil],
      ['lease_type', 'lease_type', 'nvarchar(10)', 'NULL', nil],
      ['address', 'address', 'nvarchar(100)', 'NULL', nil],
      ['city', 'city', 'nvarchar(50)', 'NULL', nil],
      ['zip_postal_code', 'zip_postal_code', 'nvarchar(10)', 'NULL', nil],
      ['inventory_code', 'inventory_code', 'nvarchar(10)', 'NULL', nil],
      ['number_of_floors', 'number_of_floors', 'int', 'NULL', nil],
      ['active_inactive', 'active_inactive', 'nvarchar(10)', 'NULL', nil],
      ['in_engie', 'in_engie', 'bit', 'NOT NULL', nil],
      ['in_maintstar', 'in_maintstar', 'bit', 'NOT NULL', nil],
      ['short_name', 'short_name', 'varchar(255)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'bss',
        table: 'buildings',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
