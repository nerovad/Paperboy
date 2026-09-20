# frozen_string_literal: true

require 'test_helper'
require_relative '../../../support/dam/fake_publishing_http'

module Dam
  module Publishing
    class OauthTest < ActiveSupport::TestCase
      CLIENT_ENV = {
        'PUBLISH_YOUTUBE_CLIENT_ID' => 'google-id', 'PUBLISH_YOUTUBE_CLIENT_SECRET' => 'google-secret',
        'PUBLISH_TIKTOK_CLIENT_KEY' => 'tiktok-key', 'PUBLISH_TIKTOK_CLIENT_SECRET' => 'tiktok-secret',
        'PUBLISH_META_CLIENT_ID' => 'meta-id', 'PUBLISH_META_CLIENT_SECRET' => 'meta-secret'
      }.freeze

      setup do
        # This suite does not roll back between tests, so the DAM tables are
        # cleared the way the other model tests clear theirs.
        Dam::Publication.delete_all
        Dam::PublishTarget.delete_all
        @previous = CLIENT_ENV.keys.index_with { |key| ENV.fetch(key, nil) }
        CLIENT_ENV.each { |key, value| ENV[key] = value }
      end

      teardown do
        @previous.each { |key, value| ENV[key] = value }
      end

      test 'Google is asked for offline access, or it issues no refresh token' do
        url = Oauth.new(target('youtube')).authorize_url(redirect_uri: 'https://paperboy.example/cb', state: 'xyz')
        params = Rack::Utils.parse_query(URI.parse(url).query)

        assert_equal 'https://accounts.google.com/o/oauth2/v2/auth', url.split('?').first
        assert_equal 'google-id', params['client_id']
        assert_equal 'offline', params['access_type']
        assert_equal 'consent', params['prompt']
        assert_equal 'xyz', params['state']
        assert_equal 'https://paperboy.example/cb', params['redirect_uri']
      end

      test 'TikTok is asked with a client key, because that is what it calls it' do
        url = Oauth.new(target('tiktok')).authorize_url(redirect_uri: 'https://paperboy.example/cb', state: 'xyz')
        params = Rack::Utils.parse_query(URI.parse(url).query)

        assert_equal 'tiktok-key', params['client_key']
        assert_nil params['client_id']
        assert_equal 'video.publish,video.upload', params['scope']
      end

      test 'a provider this server has no credentials for says so plainly' do
        ENV['PUBLISH_YOUTUBE_CLIENT_SECRET'] = nil

        assert_not Oauth.configured?('youtube')
        error = assert_raises(NotConfigured) do
          Oauth.new(target('youtube')).authorize_url(redirect_uri: 'https://paperboy.example/cb', state: 'x')
        end
        assert_match(/PUBLISH_YOUTUBE_CLIENT_SECRET/, error.message)
      end

      test 'a code is exchanged for tokens and stored on the target' do
        connected = target('youtube')
        http = Dam::FakePublishingHttp.new(
          Dam::FakePublishingHttp.response(body: { 'access_token' => 'ya29', 'refresh_token' => 'r1',
                                                   'expires_in' => 3599, 'scope' => 'youtube.upload' })
        )

        Oauth.new(connected, http: http).exchange_code!(code: 'abc', redirect_uri: 'https://paperboy.example/cb')

        assert_equal 'ya29', connected.reload.oauth_access_token
        assert_equal 'r1', connected.oauth_refresh_token
        assert_equal 'youtube.upload', connected.oauth_scope
        assert_equal 'authorization_code', http.call(0).options[:fields]['grant_type']
        assert_equal 'google-secret', http.call(0).options[:fields]['client_secret']
      end

      test 'Vimeo is sent the client as basic auth rather than in the body' do
        vimeo = Dam::PublishTarget.create!(label: 'County Vimeo', provider: 'vimeo')
        ENV['PUBLISH_VIMEO_CLIENT_ID'] = 'vimeo-id'
        ENV['PUBLISH_VIMEO_CLIENT_SECRET'] = 'vimeo-secret'
        http = Dam::FakePublishingHttp.new(Dam::FakePublishingHttp.response(body: { 'access_token' => 'v1' }))

        Oauth.new(vimeo, http: http).exchange_code!(code: 'abc', redirect_uri: 'https://paperboy.example/cb')

        fields = http.call(0).options[:fields]
        assert_nil fields['client_secret']
        assert_equal "basic #{Base64.strict_encode64('vimeo-id:vimeo-secret')}",
                     http.call(0).options[:headers]['Authorization']
        assert_equal 'v1', vimeo.reload.oauth_access_token
      ensure
        ENV['PUBLISH_VIMEO_CLIENT_ID'] = nil
        ENV['PUBLISH_VIMEO_CLIENT_SECRET'] = nil
      end

      test 'Meta renews by exchanging the token it already has' do
        meta = Dam::PublishTarget.create!(label: 'County page', provider: 'facebook', account_ref: '5150',
                                          oauth_access_token: 'short-lived', oauth_expires_at: 1.minute.from_now)
        http = Dam::FakePublishingHttp.new(
          Dam::FakePublishingHttp.response(body: { 'access_token' => 'long-lived', 'expires_in' => 5_184_000 })
        )

        assert_equal 'long-lived', Oauth.new(meta, http: http).fresh_access_token!
        assert_equal :get, http.call(0).verb
        assert_match(/fb_exchange_token=short-lived/, http.call(0).url)
      end

      test 'a token with life left in it is not renewed' do
        youtube = target('youtube')
        youtube.update!(oauth_access_token: 'still-good', oauth_refresh_token: 'r1',
                        oauth_expires_at: 2.hours.from_now)
        http = Dam::FakePublishingHttp.new

        assert_equal 'still-good', Oauth.new(youtube, http: http).fresh_access_token!
        assert_empty http.calls
      end

      test 'a refusal at the token endpoint is reported in the provider words' do
        youtube = target('youtube')
        youtube.update!(oauth_access_token: 'expired', oauth_refresh_token: 'stale',
                        oauth_expires_at: 1.minute.ago)
        http = Dam::FakePublishingHttp.new(
          Dam::FakePublishingHttp.response(code: 400, body: { 'error_description' => 'Token has been revoked.' })
        )

        error = assert_raises(NotConfigured) { Oauth.new(youtube, http: http).fresh_access_token! }
        assert_match(/Token has been revoked/, error.message)
      end

      private

      def target(provider)
        Dam::PublishTarget.create!(label: "County #{provider}", provider: provider)
      end
    end
  end
end
