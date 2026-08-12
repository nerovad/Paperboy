# frozen_string_literal: true

module Billing
  class ArchiveReportsController < BaseController
    before_action -> { require_app_feature('billing', 'archive_reports', fallback: billing_root_path) }
    before_action :load_active_billing_period
    before_action :load_reports
    before_action :load_locations

    def show
      @selected_names = Set.new
      @selected_location = @locations.first&.relative_path
    end

    def create
      @selected_names = selected_names
      @selected_location = params[:archive_location].to_s
      return update_selection if params[:selection_action].present?
      return render_error('Select at least one Billing report.') if @selected_names.empty?

      location = ArchiveLocation.find(@selected_location)
      count = ReportArchiver.new(filenames: selected_filenames, destination: location).call
      redirect_to billing_archive_reports_path,
                  notice: "#{count} Billing report files archived successfully."
    rescue ActiveRecord::RecordNotFound, ArchiveLocation::ConfigurationError,
           ReportArchiver::FileExists, SystemCallError => e
      Rails.logger.error("Billing report archive failed: #{e.class}: #{e.message}")
      render_error(e.message)
    end

    private

    def load_active_billing_period
      @active_billing_period = ActiveBillingPeriod.current
      return if @active_billing_period

      redirect_to billing_reporting_period_path,
                  alert: 'Select an active billing period before archiving Billing reports.'
    end

    def load_reports
      @reports = EmailReport.all
    end

    def load_locations
      @locations = ArchiveLocation.all
    rescue ArchiveLocation::ConfigurationError => e
      @locations = []
      flash.now[:alert] = e.message
    end

    def selected_names
      allowed = @reports.map(&:name)
      params.fetch(:reports, {}).permit(*allowed).to_h.select { |_name, value| value == '1' }.keys.to_set
    end

    def selected_filenames
      @reports.select { |report| @selected_names.include?(report.name) }.flat_map(&:filenames)
    end

    def update_selection
      @selected_names = params[:selection_action] == 'select_all' ? @reports.to_set(&:name) : Set.new
      render :show
    end

    def render_error(message)
      flash.now[:alert] = message
      render :show, status: :unprocessable_entity
    end
  end
end
