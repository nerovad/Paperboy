# frozen_string_literal: true

module DigitalAssetManagement
  # Publishing an asset, and the history of everything published.
  #
  # Creating a publication does not publish anything here: it queues
  # Dam::PublishJob and returns, because the request that asked cannot be held
  # open for a two-gigabyte upload. The row is the receipt, and the screen
  # follows it.
  class PublicationsController < BaseController
    before_action -> { require_app_feature('digital_asset_management', 'publish', fallback: digital_asset_management_root_path) }
    include Pagy::Method

    before_action :set_publication, only: %i[show retry cancel]

    def index
      @state_filter = params[:state].to_s
      @mine = params[:scope].to_s != 'everyone'
      scope = Dam::Publication.in_state(@state_filter).newest_first
      scope = scope.by_employee(dam_employee_id) if @mine
      scope = scope.where(publish_target_id: params[:publish_target_id]) if params[:publish_target_id].present?
      @pagy, @publications = pagy(:offset, scope.includes(:asset, :publish_target))
      @targets = Dam::PublishTarget.ordered
      @counts = Dam::Publication.in_state(nil).group(:status).count
    end

    def show
      @job = Dam::Job.find_by(id: @publication.job_id)
    end

    def create
      asset = Dam::Asset.find(params[:asset_id])
      target = Dam::PublishTarget.find(params[:publish_target_id])
      refusal = target.refusal_reason(asset)
      return redirect_back_to(asset, alert: "#{target.label} cannot take this asset: #{refusal}") if refusal

      publication = build_publication(asset, target)
      return redirect_back_to(asset, alert: publication.errors.full_messages.to_sentence) unless publication.save

      queue(publication)
      redirect_back_to(asset, notice: "Publishing #{asset.title} to #{target.label}.")
    end

    # A fresh row rather than a rewrite of the old one, so a retry that works
    # does not erase the failure that prompted it.
    def retry
      return redirect_to(digital_asset_management_publication_path(@publication), alert: 'That publish is still running.') if @publication.open?

      again = @publication.duplicate_for_retry(actor: current_user)
      return redirect_to(digital_asset_management_publication_path(@publication), alert: again.errors.full_messages.to_sentence) unless again.save

      queue(again)
      redirect_to digital_asset_management_publication_path(again), notice: 'Publishing again.'
    end

    # Only while it is still waiting: once the bytes are moving, stopping the
    # worker would leave the far end holding half a video with nothing here
    # saying so.
    def cancel
      return redirect_to(digital_asset_management_publication_path(@publication), alert: 'That publish has already started.') unless @publication.status == 'queued'

      @publication.update(status: 'cancelled', finished_at: Time.current)
      Dam::Job.find_by(id: @publication.job_id)&.update(status: 'cancelled', finished_at: Time.current)
      redirect_to digital_asset_management_publication_path(@publication), notice: 'Publish cancelled.'
    end

    private

    def set_publication
      @publication = Dam::Publication.find(params[:id])
    end

    def build_publication(asset, target)
      publication = Dam::Publication.new(
        asset: asset, publish_target: target, status: 'queued',
        title: params[:title].presence || asset.title,
        description: params[:description].presence || asset.description,
        privacy: params[:privacy].presence || target.default_privacy.presence || target.adapter_class.default_privacy,
        requested_by_id: dam_employee_id, requested_by_name: dam_actor_name
      )
      publication.tag_list = params[:tags].to_s.split(',')
      publication
    end

    # Every piece of DAM work shows up in the Jobs feed whether or not anyone
    # was watching the screen that started it.
    def queue(publication)
      job = Dam::Job.enqueue!(job_type: 'publish', actor: current_user, subject: publication.asset, total_items: 1)
      job.append_log("Queued for #{publication.target_label}")
      job.save
      publication.update_columns(job_id: job.id, updated_at: Time.current)
      Dam::PublishJob.perform_later(publication.id)
    end

    def redirect_back_to(asset, **flash)
      redirect_back fallback_location: digital_asset_management_asset_path(asset), **flash
    end
  end
end
