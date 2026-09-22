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
    include QueuesPublications

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
      asset = find_viewable_asset(params[:asset_id])
      require_asset_capability(asset, :publish)
      return if performed?

      target = Dam::PublishTarget.find(params[:publish_target_id])
      refusal = target.refusal_reason(asset)
      return redirect_back_to(asset, alert: "#{target.label} cannot take this asset: #{refusal}") if refusal

      publication = build_publication(asset, target, title: params[:title], description: params[:description])
      return redirect_back_to(asset, alert: publication.errors.full_messages.to_sentence) unless publication.save

      queue_publication(publication)
      redirect_back_to(asset, notice: "Publishing #{asset.title} to #{target.label}.")
    end

    # A fresh row rather than a rewrite of the old one, so a retry that works
    # does not erase the failure that prompted it.
    def retry
      return redirect_to(digital_asset_management_publication_path(@publication), alert: 'That publish is still running.') if @publication.open?

      again = @publication.duplicate_for_retry(actor: current_user)
      return redirect_to(digital_asset_management_publication_path(@publication), alert: again.errors.full_messages.to_sentence) unless again.save

      queue_publication(again)
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

    def redirect_back_to(asset, **flash)
      redirect_back fallback_location: digital_asset_management_asset_path(asset), **flash
    end
  end
end
