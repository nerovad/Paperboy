# app/controllers/lookup_tables_controller.rb
class LookupTablesController < ApplicationController
  TABLES = [
    { key: "agencies",         name: "Agencies",         table: "agencies" },
    { key: "divisions",        name: "Divisions",        table: "divisions" },
    { key: "departments",      name: "Departments",      table: "departments" },
    { key: "units",            name: "Units",            table: "units" },
    { key: "sub_units",        name: "Sub Units",        table: "sub_units" },
    { key: "activities",       name: "Activities",       table: "activities" },
    { key: "functions",        name: "Functions",        table: "functions" },
    { key: "funds",            name: "Funds",            table: "funds" },
    { key: "department_funds", name: "Department Funds", table: "department_funds" },
    { key: "major_programs",   name: "Major Programs",   table: "major_programs" },
    { key: "programs",         name: "Programs",         table: "programs" },
    { key: "phases",           name: "Phases",           table: "phases" },
    { key: "tasks",            name: "Tasks",            table: "tasks" },
    { key: "objects",          name: "Objects",          table: "objects" },
    { key: "sub_objects",      name: "Sub Objects",      table: "sub_objects" },
    { key: "revenue_sources",  name: "Revenue Sources",  table: "revenue_sources" },
  ].freeze

  before_action :set_table_config, only: [:show, :new, :create]

  def index
    @tables = TABLES
  end

  def show
    @columns = column_info(@table_config[:table])
    @rows = fetch_rows(@table_config[:table])
  end

  def new
    @columns = column_info(@table_config[:table])
  end

  def create
    table_name = @table_config[:table]
    columns = column_info(table_name)
    col_names = columns.map { |c| c[:name] }

    values = {}
    col_names.each do |col|
      values[col] = params[:record][col] if params[:record]&.key?(col)
    end

    if values.values.all?(&:blank?)
      redirect_to new_lookup_table_path(id: @table_config[:key]), alert: "All fields are blank."
      return
    end

    cols = values.keys.map { |c| connection.quote_column_name(c) }.join(", ")
    vals = values.values.map { |v| connection.quote(v) }.join(", ")

    connection.execute("INSERT INTO #{connection.quote_table_name(table_name)} (#{cols}) VALUES (#{vals})")

    redirect_to lookup_table_path(id: @table_config[:key]), notice: "Record added successfully."
  rescue => e
    redirect_to new_lookup_table_path(id: @table_config[:key]), alert: "Error: #{e.message}"
  end

  private

  def set_table_config
    @table_config = TABLES.find { |t| t[:key] == params[:id] }
    redirect_to lookup_tables_path, alert: "Table not found." unless @table_config
  end

  def column_info(table_name)
    connection.columns(table_name).map do |col|
      { name: col.name, type: col.type, sql_type: col.sql_type }
    end
  end

  def fetch_rows(table_name)
    result = connection.exec_query("SELECT * FROM #{connection.quote_table_name(table_name)}")
    result.to_a
  end

  def connection
    ActiveRecord::Base.connection
  end
end
