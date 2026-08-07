# frozen_string_literal: true

module DigitalAssetManagement
  # Where custom DAM workflows are registered and maintained.
  #
  # Running one raises a Dam::Job and returns; nothing is executed in the
  # request. The runner that picks those jobs up is deliberately not here —
  # these workflows are Ruby, Python and C++, and that dispatch belongs in a
  # worker, not in a controller action holding a request open.
  class WorkflowsController < BaseController
    before_action :set_workflow, only: %i[show edit update destroy run toggle]

    def index
      @workflows = Dam::Workflow.alphabetical
      @last_jobs = Dam::Job.where(workflow_id: @workflows.map(&:id))
                           .group(:workflow_id).maximum(:created_at)
    end

    def show
      @jobs = @workflow.jobs.newest_first.limit(20)
    end

    def new
      @workflow = Dam::Workflow.new
    end

    def create
      @workflow = Dam::Workflow.new(workflow_params)
      @workflow.created_by_id = dam_employee_id
      @workflow.created_by_name = dam_actor_name

      if @workflow.save
        redirect_to digital_asset_management_workflow_path(@workflow), notice: 'Workflow created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @workflow.update(workflow_params)
        redirect_to digital_asset_management_workflow_path(@workflow), notice: 'Workflow updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @workflow.destroy
      redirect_to digital_asset_management_workflows_path, notice: 'Workflow deleted.'
    end

    def run
      return redirect_to(digital_asset_management_workflow_path(@workflow), alert: 'That workflow is disabled.') unless @workflow.enabled?

      subject = resolve_subject
      job = Dam::Job.enqueue!(job_type: 'workflow', actor: current_user, workflow: @workflow, subject: subject,
                              total_items: subject.try(:asset_count) || 1)
      job.append_log("Queued #{@workflow.name} (#{@workflow.runtime_label})")
      job.save
      @workflow.touch(:last_run_at)

      redirect_to digital_asset_management_job_path(job), notice: "#{@workflow.name} queued."
    end

    def toggle
      @workflow.update(enabled: !@workflow.enabled?)
      redirect_back fallback_location: digital_asset_management_workflows_path,
                    notice: @workflow.enabled? ? 'Workflow enabled.' : 'Workflow disabled.'
    end

    private

    def set_workflow
      @workflow = Dam::Workflow.find(params[:id])
    end

    def workflow_params
      params.require(:workflow)
            .permit(:name, :slug, :description, :runtime, :entrypoint, :default_arguments,
                    :trigger, :schedule, :enabled, media_type_list: [])
    end

    # A run may be aimed at one asset, one collection, or nothing (the whole
    # library). Anything unrecognised runs unscoped rather than 404s.
    def resolve_subject
      case params[:subject_type]
      when 'asset' then Dam::Asset.find_by(id: params[:subject_id])
      when 'collection' then Dam::Collection.find_by(id: params[:subject_id])
      end
    end
  end
end
