# frozen_string_literal: true

module DigitalAssetManagement
  # Where the library's publishing destinations are set up.
  #
  # Its own grant, separate from Publish: connecting a county YouTube channel
  # is an administrative act, while sending a video to one that is already
  # connected is ordinary work. Plenty of people should be able to do the
  # second without being able to do the first.
  class PublishTargetsController < BaseController
    before_action -> { require_app_feature('digital_asset_management', 'publish_targets', fallback: digital_asset_management_root_path) }
    before_action :set_target, only: %i[show edit update destroy toggle disconnect]

    def index
      @targets = Dam::PublishTarget.ordered
      @counts = Dam::Publication.group(:publish_target_id).count
      @last_published = Dam::Publication.succeeded.group(:publish_target_id).maximum(:finished_at)
    end

    def show
      @publications = @target.publications.newest_first.limit(20)
      @oauth_configured = Dam::Publishing::Oauth.configured?(@target.provider) if @target.oauth?
    end

    def new
      @target = Dam::PublishTarget.new(provider: params[:provider].presence || 'youtube')
    end

    def create
      @target = Dam::PublishTarget.new(target_params)

      if @target.save
        redirect_to digital_asset_management_publish_target_path(@target),
                    notice: connect_prompt(@target)
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @target.update(target_params)
        redirect_to digital_asset_management_publish_target_path(@target), notice: 'Publish target updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # Refused while it has a history, the way a storage location holding
    # assets is: a deleted target takes the record of everything sent through
    # it with it. Disabling is what "stop using this" means here.
    def destroy
      if @target.destroy
        redirect_to digital_asset_management_publish_targets_path, notice: 'Publish target deleted.'
      else
        redirect_to digital_asset_management_publish_target_path(@target),
                    alert: "#{@target.label} has published assets, so it cannot be deleted. Disable it instead."
      end
    end

    def toggle
      @target.update(enabled: !@target.enabled?)
      redirect_back fallback_location: digital_asset_management_publish_targets_path,
                    notice: @target.enabled? ? 'Publish target enabled.' : 'Publish target disabled.'
    end

    def disconnect
      @target.disconnect!
      redirect_to digital_asset_management_publish_target_path(@target),
                  notice: "#{@target.label} is no longer connected. Nothing already published is affected."
    end

    private

    def set_target
      @target = Dam::PublishTarget.find(params[:id])
    end

    def target_params
      params.require(:publish_target)
            .permit(:label, :key, :provider, :enabled, :notes, :account_ref, :account_label,
                    :endpoint_url, :http_method, :headers, :body_style, :file_field, :default_privacy)
    end

    # A target that signs in is useless until somebody does, so saying so is
    # more use than "created".
    def connect_prompt(target)
      return 'Publish target created.' unless target.oauth?

      "Publish target created. Connect it to #{target.provider_label} before publishing to it."
    end
  end
end
