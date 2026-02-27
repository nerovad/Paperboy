class CreateOrgHierarchy < ActiveRecord::Migration[8.0]
  def change
    # Agencies
    create_table :agencies, id: false do |t|
      t.string :agency_id, limit: 3, null: false
      t.string :name, limit: 100, null: false
      t.string :long_name, limit: 100, null: false
      t.string :short_name, limit: 50, null: false
    end
    execute "ALTER TABLE agencies ADD PRIMARY KEY (agency_id)"

    # Divisions
    create_table :divisions, id: false do |t|
      t.string :agency_id, limit: 3, null: false
      t.string :division_id, limit: 4, null: false
      t.string :long_name, limit: 100, null: false
      t.string :short_name, limit: 50, null: false
    end
    execute "ALTER TABLE divisions ADD PRIMARY KEY (agency_id, division_id)"

    # Departments
    create_table :departments, id: false do |t|
      t.string :agency_id, limit: 3, null: false
      t.string :division_id, limit: 4, null: false
      t.string :department_id, limit: 4, null: false
      t.string :long_name, limit: 100, null: false
      t.string :short_name, limit: 50, null: false
    end
    execute "ALTER TABLE departments ADD PRIMARY KEY (agency_id, division_id, department_id)"

    # Units
    create_table :units, id: false do |t|
      t.string :agency_id, limit: 3, null: false
      t.string :division_id, limit: 4, null: false
      t.string :department_id, limit: 4, null: false
      t.string :unit_id, limit: 4, null: false
      t.string :long_name, limit: 100, null: false
      t.string :short_name, limit: 50, null: false
    end
    execute "ALTER TABLE units ADD PRIMARY KEY (agency_id, division_id, department_id, unit_id)"

    # Activities
    create_table :activities, id: false do |t|
      t.string :agency_id, limit: 3, null: false
      t.string :activity_id, limit: 4, null: false
      t.string :long_name, limit: 100, null: false
      t.string :short_name, limit: 50, null: false
    end
    execute "ALTER TABLE activities ADD PRIMARY KEY (agency_id, activity_id)"

    # Functions
    create_table :functions, id: false do |t|
      t.string :agency_id, limit: 3, null: false
      t.string :function_id, limit: 4, null: false
      t.string :long_name, limit: 100, null: false
      t.string :short_name, limit: 50, null: false
    end
    execute "ALTER TABLE functions ADD PRIMARY KEY (agency_id, function_id)"

    # Funds
    create_table :funds, id: false do |t|
      t.string :fund_id, limit: 4, null: false
      t.string :long_name, limit: 100, null: false
      t.string :short_name, limit: 50, null: false
      t.string :fund_class, limit: 50, null: false
      t.string :fund_category, limit: 50, null: false
      t.string :fund_type, limit: 50, null: false
      t.string :fund_group, limit: 50, null: false
      t.string :cafr_type, limit: 50, null: false
    end
    execute "ALTER TABLE funds ADD PRIMARY KEY (fund_id)"

    # Department Funds
    create_table :department_funds, id: false do |t|
      t.string :agency_id, limit: 3, null: false
      t.string :fund_id, limit: 4, null: false
    end
    execute "ALTER TABLE department_funds ADD PRIMARY KEY (agency_id, fund_id)"

    # Major Programs
    create_table :major_programs, id: false do |t|
      t.string :agency_id, limit: 3, null: false
      t.string :major_program_id, limit: 10, null: false
      t.string :long_name, limit: 100, null: false
      t.string :short_name, limit: 50, null: false
    end
    execute "ALTER TABLE major_programs ADD PRIMARY KEY (agency_id, major_program_id)"

    # Programs
    create_table :programs, id: false do |t|
      t.string :agency_id, limit: 3, null: false
      t.string :program_id, limit: 10, null: false
      t.string :major_program_id, limit: 10, null: false
      t.string :long_name, limit: 100, null: false
      t.string :short_name, limit: 50, null: false
    end
    execute "ALTER TABLE programs ADD PRIMARY KEY (agency_id, program_id, major_program_id)"

    # Phases
    create_table :phases, id: false do |t|
      t.string :agency_id, limit: 3, null: false
      t.string :phase_id, limit: 6, null: false
      t.string :long_name, limit: 100, null: false
      t.string :short_name, limit: 50, null: false
    end
    execute "ALTER TABLE phases ADD PRIMARY KEY (agency_id, phase_id)"

    # Tasks (org hierarchy)
    create_table :tasks, id: false do |t|
      t.string :agency_id, limit: 3, null: false
      t.string :task_id, limit: 4, null: false
      t.string :long_name, limit: 100, null: false
      t.string :short_name, limit: 50, null: false
    end
    execute "ALTER TABLE tasks ADD PRIMARY KEY (agency_id, task_id)"

    # Revenue Sources
    create_table :revenue_sources, id: false do |t|
      t.integer :revenue_id, limit: 2, null: false
      t.string :long_name, limit: 100, null: false
      t.string :short_name, limit: 50, null: false
    end
    execute "ALTER TABLE revenue_sources ADD PRIMARY KEY (revenue_id)"

    # Objects
    create_table :objects, id: false do |t|
      t.integer :object_id, limit: 2, null: false
      t.string :long_name, limit: 100, null: false
      t.string :short_name, limit: 50, null: false
    end
    execute "ALTER TABLE objects ADD PRIMARY KEY (object_id)"

    # Sub Objects
    create_table :sub_objects, id: false do |t|
      t.string :agency_id, limit: 3, null: false
      t.integer :object_id, limit: 2, null: false
      t.string :sub_object_id, limit: 4, null: false
    end
    execute "ALTER TABLE sub_objects ADD PRIMARY KEY (agency_id, object_id, sub_object_id)"

    # Sub Units
    create_table :sub_units, id: false do |t|
      t.string :agency_id, limit: 3, null: false
      t.string :unit_id, limit: 4, null: false
      t.string :subunit_id, limit: 4, null: false
      t.string :short_name, limit: 50, null: false
    end
    execute "ALTER TABLE sub_units ADD PRIMARY KEY (agency_id, unit_id, subunit_id)"
  end
end
