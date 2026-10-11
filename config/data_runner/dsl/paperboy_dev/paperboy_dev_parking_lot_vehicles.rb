# frozen_string_literal: true

[
  'Paperboy_dev_parking_lot_vehicles',
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
    dependency: 'Paperboy_dev_parking_lot_submissions',
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'Paperboy_Dev',
      schema: 'dbo',
      table: 'parking_lot_vehicles',
      local: 'paperboy_dev_parking_lot_vehicles.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['id', 'id', 'bigint', 'IDENTITY(1,1) NOT NULL', nil],
      ['parking_lot_submission_id', 'parking_lot_submission_id', 'bigint', 'NOT NULL', nil],
      ['make', 'make', 'nvarchar(50)', 'NULL', nil],
      ['model', 'model', 'nvarchar(50)', 'NULL', nil],
      ['color', 'color', 'nvarchar(20)', 'NULL', nil],
      ['year', 'year', 'int', 'NULL', nil],
      ['license_plate', 'license_plate', 'nvarchar(15)', 'NULL', nil],
      ['parking_lot', 'parking_lot', 'nvarchar(100)', 'NULL', nil],
      ['created_at', 'created_at', 'datetime2(6)', 'NOT NULL', nil],
      ['updated_at', 'updated_at', 'datetime2(6)', 'NOT NULL', nil],
      ['other_parking_lot', 'other_parking_lot', 'nvarchar(100)', 'NULL', nil],
      ['permit_type', 'permit_type', 'nvarchar(max)', 'NULL', nil],
      ['carpool_participants', 'carpool_participants', 'nvarchar(max)', 'NULL', nil],
      ['other_permit_type', 'other_permit_type', 'nvarchar(200)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'pb',
        table: 'parking_lot_vehicles',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]
