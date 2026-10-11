# frozen_string_literal: true

[
  'Paperboy_dev_fleet_vehicles',
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
      table: 'fleet_vehicles',
      local: 'paperboy_dev_fleet_vehicles.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['fleet_vehicle_garaging_form_id', 'fleet_vehicle_garaging_form_id', 'bigint', 'NULL', nil],
      ['year', 'year', 'int', 'NULL', nil],
      ['make', 'make', 'nvarchar(50)', 'NULL', nil],
      ['model', 'model', 'nvarchar(50)', 'NULL', nil],
      ['color', 'color', 'nvarchar(20)', 'NULL', nil],
      ['license_plate', 'license_plate', 'nvarchar(15)', 'NULL', nil],
      ['garaging_location', 'garaging_location', 'nvarchar(200)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['take_home', 'take_home', 'nvarchar(3)', 'NULL', nil],
      ['secondary_garaging_location', 'secondary_garaging_location', 'nvarchar(200)', 'NULL', nil],
      ['vehicle_number', 'vehicle_number', 'nvarchar(20)', 'NULL', nil],
      ['budget_unit', 'budget_unit', 'nvarchar(10)', 'NULL', nil],
      ['agency', 'agency', 'nvarchar(4000)', 'NULL', nil],
      ['last_updated_by', 'last_updated_by', 'nvarchar(4000)', 'NULL', nil],
      ['last_updated_by_employee_id', 'last_updated_by_employee_id', 'int', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'fleet_vehicles',
        inject: { mode: :delete_insert, delete_where: '1 = 1' }
      }
    ]
  }
]
