# frozen_string_literal: true

module DigitalAssetManagement
  # Status feed for everything the DAM runs in the background — ingests,
  # exports, shares and custom workflow runs.
  class JobsController < BaseController
    before_action -> { require_app_feature('digital_asset_management', 'jobs', fallback: digital_asset_management_root_path) }
    include Pagy::Method

    before_action :set_job, only: %i[show retry cancel]

    def index
      scope = Dam::Job.includes(:workflow).newest_first
      scope = scope.of_type(params[:job_type]) if Dam::Job::JOB_TYPES.key?(params[:job_type])
      scope = scope.where(status: params[:status]) if Dam::Job::STATUSES.include?(params[:status])

      @pagy, @jobs = pagy(:offset, scope)
      @counts = Dam::Job.group(:status).count
    end

    def show; end

    # Re-runs by raising a fresh job rather than resetting this one, so the
    # failure stays in the feed with its log intact.
    def retry
      copy = Dam::Job.enqueue!(job_type: @job.job_type, actor: current_user, workflow: @job.workflow,
                               subject: @job.subject, total_items: @job.total_items)
      redirect_to digital_asset_management_job_path(copy), notice: 'Job re-queued.'
    end

    def cancel
      return redirect_to(digital_asset_management_job_path(@job), alert: 'That job has already finished.') unless @job.open?

      @job.update(status: 'cancelled', finished_at: Time.current)
      redirect_to digital_asset_management_job_path(@job), notice: 'Job cancelled.'
    end

    private

    def set_job
      @job = Dam::Job.find(params[:id])
    end
  end
end
