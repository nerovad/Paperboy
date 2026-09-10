# frozen_string_literal: true

module DataRunner
  module DataRefreshable
    extend ActiveSupport::Concern

    included do
      before_action :load_data_refresh_groups, only: %i[show update]
      before_action :set_data_refresh_run, only: %i[progress status log]

      helper_method :data_refresh_form_path, :data_refresh_progress_path,
                    :data_refresh_status_path, :data_refresh_log_path,
                    :data_refresh_progress_tracker_locals, :data_refresh_app_label,
                    :data_refresh_cancel_path, :data_refresh_css_class,
                    :data_refresh_unit_name
    end

    def show; end

    def update
      run = data_refresh_service.run!(data_refresh_group_values, requested_by: current_user.email,
                                                                 selected_entries: data_refresh_selected_entries)
      return redirect_to data_refresh_form_path, notice: 'No Data Runner groups were selected.' unless run

      redirect_to data_refresh_progress_path(run),
                  notice: "Data refresh started for #{helpers.pluralize(run.total_count, data_refresh_unit_name)}."
    rescue GroupRefresh::ActiveRun
      run = GroupRun.active.find_by!(group_name: data_refresh_service.group_run_name)
      redirect_to data_refresh_progress_path(run), alert: "#{data_refresh_app_label} data refresh is already running."
    rescue GroupRefresh::QueueUnavailable => e
      Rails.logger.error("#{data_refresh_app_label} data refresh queue unavailable: #{e.message}")
      redirect_to data_refresh_form_path, alert: 'The data refresh could not be queued because Redis is unavailable.'
    rescue ActionController::ParameterMissing, ArgumentError, KeyError => e
      Rails.logger.error("#{data_refresh_app_label} data refresh failed: #{e.class}: #{e.message}")
      redirect_to data_refresh_form_path, alert: 'The data refresh could not be started.'
    end

    def restart
      previous_run = GroupRun.find_by!(id: params.require(:run_id),
                                       group_name: data_refresh_service.group_run_name)
      entries = data_refresh_service.restart_entries(previous_run)
      run = GroupRefresh.restart!(group: data_refresh_service.group_run_name, entries: entries,
                                  requested_by: current_user.email)
      redirect_to data_refresh_progress_path(run), notice: "Data refresh restarted for #{run.total_count} DSLs."
    rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing, KeyError => e
      Rails.logger.error("#{data_refresh_app_label} data refresh restart failed: #{e.class}: #{e.message}")
      redirect_to data_refresh_form_path, alert: 'The data refresh could not be restarted.'
    end

    def progress; end

    def log
      @output = TaskRunner.output!(@run.run_id)
    end

    private

    def load_data_refresh_groups
      @groups = data_refresh_service.groups(end_date: data_refresh_end_date)
      @refresh_entries = data_refresh_preview_entries
    end

    def data_refresh_preview_entries = []

    def data_refresh_group_values
      params.require(:groups).permit(*data_refresh_service.group_configuration.keys).to_h
    end

    def data_refresh_selected_entries
      return unless params.key?(:selected_oms_numbers)

      params.permit(selected_oms_numbers: []).fetch(:selected_oms_numbers)
    end

    def set_data_refresh_run
      @run = GroupRun.includes(:items).find_by!(id: params[:run_id],
                                                group_name: data_refresh_service.group_run_name)
    end

    def data_refresh_end_date
      nil
    end

    def render_data_refresh_status
      render partial: 'shared/progress_tracker', locals: data_refresh_progress_tracker_locals(@run.reload)
    end

    def data_refresh_progress_tracker_locals(run)
      {
        run: run,
        restart_path: data_refresh_restart_path(run_id: run.id),
        interrupted_restart_path: data_refresh_restart_path(run_id: run.id),
        restart_confirmation: "Restart the #{data_refresh_app_label} data refresh?",
        log_path: data_refresh_log_path(run),
        return_path: data_refresh_form_path,
        return_label: "Return to #{data_refresh_app_label}",
        unit_name: data_refresh_unit_name
      }
    end

    def data_refresh_unit_name = 'DSL'
  end
end
