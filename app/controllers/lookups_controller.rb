# frozen_string_literal: true

# app/controllers/lookups_controller.rb
class LookupsController < ApplicationController
  def agencies
    @agency_options = Agency
                      .order(:long_name)
                      .pluck(:long_name, :agency_id)

    respond_to do |format|
      format.turbo_stream
      format.json { render json: @agency_options }
      format.html { head :not_acceptable }
    end
  end

  def divisions
    @division_options = Division
                        .where(agency_id: params[:agency])
                        .order(:long_name)
                        .pluck(:long_name, :division_id)

    respond_to do |format|
      format.turbo_stream
      format.json { render json: @division_options }
      format.html { head :not_acceptable }
    end
  end

  def departments
    @department_options = Department
                          .where(division_id: params[:division])
                          .order(:long_name)
                          .pluck(:long_name, :department_id)

    respond_to do |format|
      format.turbo_stream
      format.json { render json: @department_options }
      format.html { head :not_acceptable }
    end
  end

  def units
    # Department-scoped (the agency→division→department→unit cascade) or, for the
    # contractor admin's shorter agency→unit cascade, agency-scoped directly off
    # Unit.agency_id (populated for every unit).
    scope =
      if params[:department].present?
        Unit.where(department_id: params[:department])
      elsif params[:agency].present?
        Unit.where(agency_id: params[:agency])
      else
        Unit.none
      end

    @unit_options = scope.order(:unit_id).map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }

    respond_to do |format|
      format.turbo_stream
      format.json { render json: @unit_options }
      format.html { head :not_acceptable }
    end
  end

  # Employees in a given unit, as [label, employee_id] pairs for a searchable
  # supervisor select. Requires a unit so the list stays scoped/manageable.
  def supervisors
    return render(json: []) if params[:unit].blank?

    options = Employee.where(unit: params[:unit])
                      .order(:last_name, :first_name)
                      .map { |e| ["#{e.last_name}, #{e.first_name} (#{e.id})", e.id] }

    render json: options
  end

  def employees
    scope = Employee.order(:last_name)
    scope = scope.where(agency: params[:agency]) if params[:agency].present?

    column = params[:column].presence || 'full_name'
    allowed_columns = %w[full_name first_name last_name email]
    column = 'full_name' unless allowed_columns.include?(column)

    options = case column
              when 'full_name'
                scope.map { |e| "#{e.last_name}, #{e.first_name}" }
              when 'first_name'
                scope.pluck(:first_name).uniq
              when 'last_name'
                scope.pluck(:last_name).uniq
              when 'email'
                scope.pluck(:email).compact.uniq
              end

    render json: options
  end

  # Distinct categories for a categorized data source (e.g. injury_classifications).
  # Returns [label, id] pairs to match the agencies endpoint shape.
  def categories
    return render json: [], status: :not_found unless FormField.categorized_source?(params[:source])

    render json: FormField.category_options_for(params[:source])
  end

  # --- Generic ("custom") lookup builder endpoints ---------------------------
  # Schema introspection for the form builder's custom data source. database is
  # a logical name (paperboy/gsabss); names are validated and quoted before SQL.

  def tables
    conn = FormLookup.connection_for(params[:database])
    return render(json: []) unless conn

    names = conn.tables
    names += conn.views if conn.respond_to?(:views)
    render json: names.uniq.sort
  end

  def columns
    conn = FormLookup.connection_for(params[:database])
    return render(json: []) unless conn && FormLookup.table_exists_in?(conn, params[:table])

    render json: conn.columns(params[:table]).map(&:name)
  end

  def category_values
    conn = FormLookup.connection_for(params[:database])
    table = params[:table]
    column = params[:column]
    return render(json: []) unless conn && FormLookup.table_exists_in?(conn, table)
    return render(json: []) unless conn.columns(table).map(&:name).include?(column)

    qt = conn.quote_table_name(table)
    qc = conn.quote_column_name(column)
    values = conn.exec_query("SELECT DISTINCT #{qc} AS val FROM #{qt} ORDER BY #{qc}")
                 .map { |r| r['val'] }.compact
    render json: values
  end
end
