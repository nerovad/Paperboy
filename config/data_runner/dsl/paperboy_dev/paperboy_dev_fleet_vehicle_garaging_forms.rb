# frozen_string_literal: true

[
  'Paperboy_dev_fleet_vehicle_garaging_forms',
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
    dependency: 'Paperboy_dev_fleet_vehicles',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'fleet_vehicle_garaging_forms',
      local: 'paperboy_dev_fleet_vehicle_garaging_forms.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['employee_id', 'employee_id', 'nvarchar(4000)', 'NULL', nil],
      ['name', 'name', 'nvarchar(4000)', 'NULL', nil],
      ['phone', 'phone', 'nvarchar(4000)', 'NULL', nil],
      ['email', 'email', 'nvarchar(4000)', 'NULL', nil],
      ['agency', 'agency', 'nvarchar(4000)', 'NULL', nil],
      ['division', 'division', 'nvarchar(4000)', 'NULL', nil],
      ['department', 'department', 'nvarchar(4000)', 'NULL', nil],
      ['unit', 'unit', 'nvarchar(4000)', 'NULL', nil],
      ['status', 'status', 'nvarchar(4000)', 'NOT NULL', nil],
      ['approver_id', 'approver_id', 'nvarchar(4000)', 'NULL', nil],
      ['deny_reason', 'deny_reason', 'nvarchar(max)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['location', 'location', 'nvarchar(4000)', 'NULL', nil],
      ['vehicle_number', 'vehicle_number', 'nvarchar(20)', 'NULL', nil],
      ['year', 'year', 'int', 'NULL', nil],
      ['make', 'make', 'nvarchar(50)', 'NULL', nil],
      ['model', 'model', 'nvarchar(50)', 'NULL', nil],
      ['is_this_a_take_home_vehicle', 'is_this_a_take_home_vehicle', 'nvarchar(3)', 'NULL', nil],
      ['other_location', 'other_location', 'nvarchar(200)', 'NULL', nil],
      ['do_you_have_a_secondary_location', 'do_you_have_a_secondary_location', 'nvarchar(3)', 'NULL', nil],
      ['secondary_location', 'secondary_location', 'nvarchar(200)', 'NULL', nil],
      ['other_secondary_location', 'other_secondary_location', 'nvarchar(200)', 'NULL', nil],
      ['last_known_location', 'last_known_location', 'nvarchar(200)', 'NULL', nil],
      ['fleet_vehicle_id', 'fleet_vehicle_id', 'bigint', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'fleet_vehicle_garaging_forms',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
