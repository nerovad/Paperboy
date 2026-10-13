# frozen_string_literal: true

module Aim
  # Fiscal report templates (#131): named layouts each agency group saves and
  # picks from when downloading the report, beside the group's own Default.
  # Anyone who works a group's Fiscal manages its templates; the list follows
  # Managing.
  class ReportTemplatesController < BaseController
    before_action :require_fiscal
    before_action :set_template, only: %i[edit update destroy]

    def index
      @groups = helpers.aim_managing_groups || helpers.aim_agency_groups.all
      @templates = Aim::ReportTemplate.where(agency_group_id: @groups.map(&:id)).by_name.group_by(&:agency_group_id)
    end

    def new
      group = workable_group(params[:agency_group_id]) || workable_groups.first
      source = Aim::ReportTemplate.find_by(id: params[:copy], agency_group_id: workable_groups.map(&:id)) || group
      @template = Aim::ReportTemplate.new(agency_group: group, export_format: source&.export_format || 'csv',
                                          export_columns: source&.export_columns)
    end

    def create
      @template = Aim::ReportTemplate.new(agency_group: workable_group(params[:agency_group_id]))
      save_template('Template saved.')
    end

    def edit; end

    def update = save_template('Template saved.')

    def destroy
      @template.destroy!
      redirect_to aim_report_templates_path, notice: "#{@template.name} deleted."
    end

    private

    def workable_groups = helpers.aim_fiscal_reach || helpers.aim_agency_groups.all

    def workable_group(id) = workable_groups.find { |group| group.id == id.to_i }

    def set_template
      @template = Aim::ReportTemplate.find_by(id: params[:id], agency_group_id: workable_groups.map(&:id))
      redirect_to aim_report_templates_path, alert: 'That template is not one of your groups\'.' if @template.nil?
    end

    def save_template(notice)
      return redirect_to(aim_report_templates_path, alert: 'Pick one of your agency groups.') if @template.agency_group.nil?

      @template.assign_attributes(name: params[:name], export_format: params[:export_format].presence || 'csv',
                                  export_column_list: Array(params[:export_columns]),
                                  export_headers: params.fetch(:export_headers, {}).permit(*Aim::FiscalExport::COLUMNS).to_h,
                                  updated_by: current_user_email)
      @template.save!
      redirect_to aim_report_templates_path, notice: notice
    rescue ActiveRecord::RecordInvalid
      render(@template.persisted? ? :edit : :new, status: :unprocessable_content)
    end
  end
end
