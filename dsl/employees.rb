# frozen_string_literal: true

[
  'Employees',
  {
    steps: {
      enabled: false,
      manual_steps: Workflow::MANUAL_STEPS,
      scheduled: {
        frequency: :daily,
        steps: Workflow::SCHEDULED_STEPS
      }
    },
    group: {
      name: 'human_resources'
    },
    source: {
      location: '/mnt/i/BUSINESS_SUPPORT/DataRunner/01_Download/employees.xlsx',
      local: 'employees.xlsx',
      format: :xlsx,
      strategy: :copy
    },
    to_csv: {
      sheet: 0,
      header_row: 1,
      data_row: 2
    },
    header: [

      ['id',                'id',                    'int',          'NOT NULL', nil],
      ['ee_last_name',      'last_name',             'nvarchar(50)', 'NOT NULL', nil],
      ['ee_first_name',     'first_name',            'nvarchar(50)', 'NOT NULL', nil],
      ['job_title',         'job_title',             'nvarchar(50)', 'NULL',     nil],
      ['work_phone',        'work_phone',            'nvarchar(20)', 'NULL',     lambda { |row|
        phone = row['work_phone'].to_s.strip
        phone.empty? ? '805-555-1234' : phone
      }],
      ['unit',              'agency',                'nvarchar(4)',  'NULL',     nil],
      ['dept_id',           'unit',                  'nvarchar(5)',  'NULL',     nil],
      ['job_code',          'job_code',              'nvarchar(5)',  'NULL',     nil],
      ['position',          'position',              'nvarchar(8)',  'NULL',     nil],
      ['pay_status',        'pay_status',            'nvarchar(1)',  'NULL',     nil],
      ['empl_class',        'job_class',             'nvarchar(2)',  'NULL',     nil],
      ['dept',              'department',            'nvarchar(50)', 'NULL',     nil],
      ['type',              'type',                  'nvarchar(1)',  'NULL',     nil],
      ['supv_id',           'supervisor_id',         'int',          'NULL',     nil],
      ['spvrsr_last_name',  'supervisor_last_name',  'nvarchar(50)', 'NULL',     nil],
      ['spvrsr_first_name', 'supervisor_first_name', 'nvarchar(50)', 'NULL',     nil],
      ['ee_email',          'person_email',          'nvarchar(50)', 'NULL',     nil],
      [nil,                 'email',                 'nvarchar(50)', 'NULL',     lambda { |row|
        ee_email = row['ee_email'].to_s.strip.downcase
        next ee_email.sub(/@ventura\.org\z/, '@venturacounty.gov') if ee_email.end_with?('@ventura.org')

        first_name = row['ee_first_name'].to_s.strip.downcase
        last_name = row['ee_last_name'].to_s.strip.downcase
        first_name.empty? || last_name.empty? ? nil : "#{first_name}.#{last_name}@venturacounty.gov"
      }]

    ],
    database_connections: [
      {
        host: 'GSASQL16',
        database: 'GSABSS',
        schema: 'dbo',
        table: 'employees',
        inject: {
          mode: :truncate_insert
        }
      }
    ]
  }
]
