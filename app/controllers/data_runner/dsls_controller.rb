# frozen_string_literal: true

module DataRunner
  class DslsController < ApplicationController
    before_action :require_login, except: :index
    before_action :set_dsl, except: %i[index new create new_group create_group update_group rename_group destroy_group refresh_group]

    def index
      @groups = DslCatalog.grouped if user_signed_in?
      @ungrouped = DslCatalog.ungrouped if user_signed_in?
      @selected_group = params[:group].presence
      @selected_entries = @groups&.fetch(@selected_group, []) || []
    end

    def show
      @source = DslFile.new(@dsl).read
      return unless params[:run_id]

      @task_output = TaskRunner.output!(params[:run_id])
      @task_status = params[:task_status] == "succeeded" ? "succeeded" : "failed"
      @task_name = params[:task_name].to_s
    end

    def new
      @commands = RakeTaskCatalog.runnable
      @selected_commands = @commands
    end

    def new_group; end

    def create_group
      group = params.require(:group_name).to_s.parameterize(separator: "_")
      return redirect_to data_runner_new_dsl_group_path, alert: "Group name is required." if group.blank?

      redirect_to data_runner_root_path(group: group), notice: "#{group.humanize} group ready."
    end

    def create
      @commands = RakeTaskCatalog.runnable
      @selected_commands = Array(params[:commands]) & @commands
      slug = DslCreator.new(name: params[:dsl_name], commands: @selected_commands).create!
      redirect_to data_runner_dsl_path(slug), notice: "#{slug} DSL created."
    rescue DslCreator::InvalidDsl => e
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    def edit
      @source = DslFile.new(@dsl).read
    end

    def update
      DslFile.new(@dsl).write!(params.require(:source))
      redirect_to data_runner_dsl_path(@dsl.slug), notice: "#{@dsl.key} saved."
    rescue SyntaxError => e
      @source = params[:source]
      flash.now[:alert] = e.message
      render :edit, status: :unprocessable_entity
    end

    def update_group
      group = params.require(:group).to_s.parameterize(separator: "_")
      DslGroupUpdater.new(group: group, slugs: params[:dsl_slugs]).update!
      redirect_to data_runner_root_path(group: group), notice: "#{group.humanize} group updated."
    end

    def rename_group
      group = params.require(:group).to_s.parameterize(separator: "_")
      new_group = DslGroupUpdater.new(group: group, slugs: []).rename!(params.require(:new_group_name))
      redirect_to data_runner_root_path(group: new_group), notice: "#{group.humanize} renamed to #{new_group.humanize}."
    rescue DslGroupUpdater::DslNameConflict => e
      redirect_to data_runner_root_path(group: group),
                  alert: "Cannot rename DSL Group #{group.humanize} to DSL Name #{e.message}"
    end

    def destroy_group
      group = params.require(:group).to_s.parameterize(separator: "_")
      DslGroupUpdater.new(group: group, slugs: []).delete!
      redirect_to data_runner_root_path, notice: "#{group.humanize} group deleted.", status: :see_other
    end

    def refresh_group
      group = params.require(:group).to_s.parameterize(separator: "_")
      enabled_slugs = DslCatalog.grouped.fetch(group, []).select(&:enabled?).map(&:slug)
      result = TaskRunner.run!(task: "refresh", selector: enabled_slugs)
      redirect_to data_runner_run_path(result.id), notice: "#{group.humanize} refresh #{result.success ? 'completed' : 'failed'}."
    end

    def destroy
      deleted_files = DslDestroyer.new(@dsl).destroy!
      redirect_to data_runner_root_path,
                  notice: "#{@dsl.key} DSL and #{deleted_files.size} workflow files deleted.",
                  status: :see_other
    end

    def run
      task_name = params.require(:task_name)
      result = TaskRunner.run!(task: task_name, selector: @dsl.slug)
      task_status = result.success ? "succeeded" : "failed"
      redirect_to data_runner_dsl_path(@dsl.slug, run_id: result.id, task_status: task_status, task_name: task_name)
    rescue ArgumentError => e
      redirect_to data_runner_dsl_path(@dsl.slug), alert: e.message
    end

    def outputs
      outputs = WorkflowOutputs.new(@dsl)
      @files = outputs.files
      @backup_files = outputs.backup_files
    end

    def output
      outputs = WorkflowOutputs.new(@dsl)
      file = outputs.find!(params[:path])
      return send_file(file, filename: file.basename.to_s, disposition: :attachment) if params[:download] == "1"

      @backup_output = outputs.backup_files.include?(file)
      @output = WorkflowOutputPresenter.new(file, header_row: @dsl.config.dig(:to_csv, :header_row))
      render :output, formats: [ :html ]
    end

    private

    def set_dsl
      @dsl = DslCatalog.find!(params[:name])
    end
  end
end
