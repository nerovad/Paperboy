# frozen_string_literal: true

module DataRunner
  class GroupRefreshesController < ApplicationController
    before_action :require_login
    before_action -> { require_app_feature('data_runner', 'manage_groups', fallback: data_runner_root_path) }

    def index
      @groups = helpers.permitted_grouped_dsls
      @ungrouped = helpers.permitted_ungrouped_dsls
      @selected_group = params[:group].presence&.parameterize(separator: '_')
      @selected_entries = @groups.fetch(@selected_group, [])
      @active_group_run = GroupRun.active.find_by(group_name: @selected_group) if @selected_group

      render 'data_runner/dsls/index'
    end

    def create
      group = params.require(:group).to_s.parameterize(separator: '_')
      entries = DslCatalog.grouped.fetch(group, []).select(&:enabled?)
      operation = params[:restart] == '1' ? :restart! : :start!
      run = GroupRefresh.public_send(operation, group: group, entries: entries, requested_by: current_user.email)
      redirect_to data_runner_group_run_path(run),
                  notice: "#{group.humanize} refresh #{'re' if operation == :restart!}started for #{entries.size} DSLs."
    rescue GroupRefresh::ActiveRun
      run = GroupRun.active.find_by!(group_name: group)
      redirect_to data_runner_group_run_path(run), alert: "#{group.humanize} refresh is already running."
    rescue GroupRefresh::QueueUnavailable => e
      Rails.logger.error("Data Runner group refresh queue unavailable: #{e.message}")
      redirect_to data_runner_root_path(group: group),
                  alert: 'The refresh could not be queued because Redis is unavailable.'
    end
  end
end
