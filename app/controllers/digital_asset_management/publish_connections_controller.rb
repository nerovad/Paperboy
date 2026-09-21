# frozen_string_literal: true

module DigitalAssetManagement
  # The OAuth round trip that connects a target to an account.
  #
  # One callback address for every provider, because each of them has to have
  # it registered by hand against the application, and five addresses would be
  # five things to get wrong. Which target is being connected rides in the
  # state parameter, checked against the session on the way back so a link
  # somebody was sent cannot attach an account to a target of their choosing.
  class PublishConnectionsController < BaseController
    before_action -> { require_app_feature('digital_asset_management', 'publish_targets', fallback: digital_asset_management_root_path) }

    def create
      target = Dam::PublishTarget.find(params[:id])
      state = SecureRandom.urlsafe_base64(24)
      session[:dam_publish_oauth] = { 'state' => state, 'target_id' => target.id }

      redirect_to Dam::Publishing::Oauth.new(target).authorize_url(redirect_uri: callback_url, state: state),
                  allow_other_host: true
    rescue Dam::Publishing::Error => e
      redirect_to digital_asset_management_publish_targets_path, alert: e.message
    end

    def callback
      pending = session.delete(:dam_publish_oauth).to_h
      target = Dam::PublishTarget.find_by(id: pending['target_id'])
      refused = refusal(pending, target)
      return redirect_to(digital_asset_management_publish_targets_path, alert: refused) if refused

      Dam::Publishing::Oauth.new(target).exchange_code!(code: params[:code], redirect_uri: callback_url, actor: current_user)
      redirect_to digital_asset_management_publish_target_path(target),
                  notice: "#{target.label} is connected to #{target.provider_label}."
    rescue Dam::Publishing::Error => e
      redirect_to digital_asset_management_publish_target_path(target), alert: e.message
    end

    private

    # Registered with each provider by hand, so it must not vary with how the
    # app was reached. The public address wins where there is one; .env can
    # override it outright for an install behind a proxy that rewrites paths.
    def callback_url
      ENV.fetch('PUBLISH_OAUTH_REDIRECT_URI', nil).presence ||
        "#{Dam::Publishing.public_base_url.presence || request.base_url}/digital_asset_management/publish_connections/callback"
    end

    # Why this callback cannot be honoured, or nil when it can.
    def refusal(pending, target)
      service = target&.provider_label || 'The service'
      return "#{service} refused: #{params[:error_description].presence || params[:error]}" if params[:error].present?
      return 'That connection did not start here. Try again from the target.' unless started_here?(pending)
      return 'That publish target no longer exists.' if target.nil?
      return 'The service sent no authorization code back.' if params[:code].blank?

      nil
    end

    # The state we sent, coming back unchanged, is the only thing tying this
    # redirect to the person who started it.
    def started_here?(pending)
      pending['state'].present? &&
        ActiveSupport::SecurityUtils.secure_compare(pending['state'].to_s, params[:state].to_s)
    end
  end
end
