# frozen_string_literal: true

module Dam
  module Publishing
    # The consent dance each provider insists on, and the renewals afterwards.
    #
    # The application's identity — client id and secret — is per host and
    # lives in .env, because it belongs to the installation. What comes back
    # belongs to the account somebody connected, so it is stored on the target
    # and encrypted there.
    #
    # The four flows differ in small, annoying ways: TikTok calls the client
    # id a client key, Vimeo wants it as Basic auth, Meta exchanges an old
    # token for a longer one instead of issuing a refresh token, and Google
    # only hands over a refresh token the first time consent is given. Those
    # differences are the table below, and nothing else in the app knows about
    # them.
    class Oauth
      # A token this close to expiry is renewed before an upload starts, so a
      # ninety-minute transfer does not die at minute sixty-one.
      RENEW_WITHIN = 10.minutes

      CONFIG = {
        'youtube' => {
          label: 'YouTube',
          authorize_url: 'https://accounts.google.com/o/oauth2/v2/auth',
          token_url: 'https://oauth2.googleapis.com/token',
          scope: 'https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/youtube.readonly',
          client_id_env: 'PUBLISH_YOUTUBE_CLIENT_ID',
          client_secret_env: 'PUBLISH_YOUTUBE_CLIENT_SECRET',
          # Google issues a refresh token on first consent only; asking for
          # consent every time is what makes reconnecting a target work.
          authorize_params: { access_type: 'offline', prompt: 'consent' },
          refresh_style: :refresh_token
        },
        'vimeo' => {
          label: 'Vimeo',
          authorize_url: 'https://api.vimeo.com/oauth/authorize',
          token_url: 'https://api.vimeo.com/oauth/access_token',
          scope: 'public private create edit upload video_files',
          client_id_env: 'PUBLISH_VIMEO_CLIENT_ID',
          client_secret_env: 'PUBLISH_VIMEO_CLIENT_SECRET',
          auth_style: :basic,
          # Vimeo's tokens do not expire and it issues no refresh token.
          refresh_style: :none
        },
        'facebook' => {
          label: 'Facebook',
          authorize_url: 'https://www.facebook.com/v21.0/dialog/oauth',
          token_url: 'https://graph.facebook.com/v21.0/oauth/access_token',
          scope: 'pages_show_list,pages_read_engagement,pages_manage_posts',
          client_id_env: 'PUBLISH_META_CLIENT_ID',
          client_secret_env: 'PUBLISH_META_CLIENT_SECRET',
          token_method: :get,
          refresh_style: :exchange
        },
        'instagram' => {
          label: 'Instagram',
          authorize_url: 'https://www.facebook.com/v21.0/dialog/oauth',
          token_url: 'https://graph.facebook.com/v21.0/oauth/access_token',
          scope: 'instagram_basic,instagram_content_publish,pages_show_list,business_management',
          client_id_env: 'PUBLISH_META_CLIENT_ID',
          client_secret_env: 'PUBLISH_META_CLIENT_SECRET',
          token_method: :get,
          refresh_style: :exchange
        },
        'tiktok' => {
          label: 'TikTok',
          authorize_url: 'https://www.tiktok.com/v2/auth/authorize/',
          token_url: 'https://open.tiktokapis.com/v2/oauth/token/',
          scope: 'video.publish,video.upload',
          client_id_env: 'PUBLISH_TIKTOK_CLIENT_KEY',
          client_secret_env: 'PUBLISH_TIKTOK_CLIENT_SECRET',
          # TikTok spells the client id "client_key", everywhere, including in
          # the authorize redirect.
          client_id_param: 'client_key',
          refresh_style: :refresh_token
        }
      }.freeze

      class << self
        def config_for(provider)
          CONFIG.fetch(provider.to_s) { raise NotConfigured, "#{provider} does not sign in with OAuth" }
        end

        def supports?(provider) = CONFIG.key?(provider.to_s)

        # Whether this host has been given the application's identity for a
        # provider. False is a normal state — it means nobody has registered
        # the app with that service yet — so the screen says so rather than
        # offering a Connect button that can only fail.
        def configured?(provider)
          return false unless supports?(provider)

          config = config_for(provider)
          ENV[config[:client_id_env]].present? && ENV[config[:client_secret_env]].present?
        end

        def client_for(provider)
          config = config_for(provider)
          missing = [config[:client_id_env], config[:client_secret_env]].reject { |key| ENV[key].present? }
          raise NotConfigured, "#{config[:label]} is not set up on this server: #{missing.join(' and ')} unset" if missing.any?

          { id: ENV.fetch(config[:client_id_env]), secret: ENV.fetch(config[:client_secret_env]) }
        end

        def env_keys_for(provider)
          config = config_for(provider)
          [config[:client_id_env], config[:client_secret_env]]
        end
      end

      def initialize(target, http: Http.new)
        @target = target
        @http = http
        @config = self.class.config_for(target.provider)
      end

      def authorize_url(redirect_uri:, state:)
        client = self.class.client_for(@target.provider)
        params = {
          client_id_param => client[:id],
          'redirect_uri' => redirect_uri,
          'response_type' => 'code',
          'scope' => @config[:scope],
          'state' => state
        }.merge(@config.fetch(:authorize_params, {}).transform_keys(&:to_s))

        "#{@config[:authorize_url]}?#{params.to_query}"
      end

      # Turns the code the provider redirected back with into stored tokens.
      def exchange_code!(code:, redirect_uri:, actor: nil)
        client = self.class.client_for(@target.provider)
        fields = {
          client_id_param => client[:id],
          'client_secret' => client[:secret],
          'code' => code,
          'grant_type' => 'authorization_code',
          'redirect_uri' => redirect_uri
        }
        fields = fields.except(client_id_param, 'client_secret') if basic_auth?

        @target.record_connection!(token_request(fields), actor: actor)
      end

      # The access token to publish with, renewed first when it is about to
      # run out. Providers that never expire, and those we cannot renew, fall
      # through to whatever is stored.
      def fresh_access_token!
        refresh! if renewable? && expiring?
        raise NotConfigured, "#{@target.label} is not connected to #{@config[:label]} yet" if @target.oauth_access_token.blank?

        @target.oauth_access_token
      end

      def refresh!
        client = self.class.client_for(@target.provider)
        fields =
          case @config[:refresh_style]
          when :refresh_token
            { client_id_param => client[:id], 'client_secret' => client[:secret],
              'grant_type' => 'refresh_token', 'refresh_token' => @target.oauth_refresh_token }
          when :exchange
            { 'client_id' => client[:id], 'client_secret' => client[:secret],
              'grant_type' => 'fb_exchange_token', 'fb_exchange_token' => @target.oauth_access_token }
          else
            return @target.oauth_access_token
          end

        @target.record_connection!(token_request(fields))
        @target.oauth_access_token
      end

      private

      def client_id_param = @config.fetch(:client_id_param, 'client_id')

      def basic_auth? = @config[:auth_style] == :basic

      def renewable?
        case @config[:refresh_style]
        when :refresh_token then @target.oauth_refresh_token.present?
        when :exchange then @target.oauth_access_token.present?
        else false
        end
      end

      # A token with no expiry recorded is left alone: Vimeo's never expire,
      # and renewing one this app was never told the life of would mean a
      # round trip before every single publish.
      def expiring? = @target.oauth_expires_at.present? && @target.oauth_expires_at < RENEW_WITHIN.from_now

      def token_request(fields)
        response = post_tokens(fields)
        raise NotConfigured, "#{@config[:label]} refused the connection: #{response.error_message}" unless response.success?

        payload = response.json
        raise NotConfigured, "#{@config[:label]} returned no access token" if payload['access_token'].blank?

        { access_token: payload['access_token'], refresh_token: payload['refresh_token'],
          expires_in: payload['expires_in'], scope: Array(payload['scope']).join(' ').presence }
      end

      def post_tokens(fields)
        headers = { 'Accept' => 'application/json' }
        if basic_auth?
          client = self.class.client_for(@target.provider)
          headers['Authorization'] = "basic #{Base64.strict_encode64("#{client[:id]}:#{client[:secret]}")}"
        end

        return @http.get("#{@config[:token_url]}?#{fields.to_query}", headers: headers) if @config[:token_method] == :get

        @http.post_form(@config[:token_url], fields, headers: headers)
      end
    end
  end
end
