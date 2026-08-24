# frozen_string_literal: true

module DataRunner
  class GroupRefreshesController < ApplicationController
    before_action :require_login
    before_action -> { require_app_feature('data_runner', 'manage_groups', fallback: data_runner_root_path) }

    def create
      group = params.require(:group).to_s.parameterize(separator: '_')
      entries = DslCatalog.control_center_grouped.fetch(group, []).select(&:enabled?)
      operation = params[:restart] == '1' ? :restart! : :start!
      run = GroupRefresh.public_send(operation, group: group, entries: entries, requested_by: current_user.email)
      redirect_to data_runner_group_run_path(run),
                  notice: "#{group.humanize} refresh #{'re' if operation == :restart!}started for #{entries.size} DSLs."
    rescue GroupRefresh::ActiveRun
      run = GroupRun.active.find_by!(group_name: group)
      redirect_to data_runner_group_run_path(run), alert: "#{group.humanize} refresh is already running."
    end
  end
end
