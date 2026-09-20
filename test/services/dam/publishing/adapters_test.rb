# frozen_string_literal: true

require 'test_helper'
require_relative '../../../support/dam/fake_publishing_http'

module Dam
  module Publishing
    # The shape of each provider's conversation: which requests, in which
    # order, carrying what. Dam::Publishing::RunnerTest covers what becomes of
    # the publication afterwards.
    class AdaptersTest < ActiveSupport::TestCase
      setup do
        # This suite does not roll back between tests, so the DAM tables are
        # cleared the way the other model tests clear theirs.
        Dam::Publication.delete_all
        Dam::PublishTarget.delete_all
        ActiveStorage::Attachment.delete_all
        ActiveStorage::Blob.delete_all
        Dam::Asset.delete_all
        Dam::StorageLocation.delete_all
        @location = Dam::StorageLocation.create!(label: 'Library', kind: 'disk')
      end

      test 'Vimeo makes the video first and sends the file to the tus link it returns' do
        target = Dam::PublishTarget.create!(label: 'County Vimeo', provider: 'vimeo', oauth_access_token: 'token')
        http = Dam::FakePublishingHttp.new(
          Dam::FakePublishingHttp.response(body: { 'uri' => '/videos/987', 'link' => 'https://vimeo.com/987',
                                                   'upload' => { 'upload_link' => 'https://tus.vimeo/987' } }),
          Dam::FakePublishingHttp.response(code: 204, headers: { 'upload-offset' => ['5'] })
        )

        result = deliver(target, http, privacy: 'unlisted')

        assert_equal '987', result.external_id
        assert_equal 'https://vimeo.com/987', result.external_url
        assert_equal 'tus', http.call(0).options[:payload][:upload][:approach]
        assert_equal({ view: 'unlisted' }, http.call(0).options[:payload][:privacy])
        assert_equal 'https://tus.vimeo/987', http.call(1).url
        assert_equal '1.0.0', http.call(1).options[:headers]['Tus-Resumable']
      end

      test 'Vimeo without an upload link is a failure rather than a video nobody sent' do
        target = Dam::PublishTarget.create!(label: 'County Vimeo', provider: 'vimeo', oauth_access_token: 'token')
        http = Dam::FakePublishingHttp.new(Dam::FakePublishingHttp.response(body: { 'uri' => '/videos/987' }))

        error = assert_raises(DeliveryFailed) { deliver(target, http) }
        assert_match(/no upload link/i, error.message)
      end

      test 'Facebook trades the connected account for the page token before posting' do
        target = Dam::PublishTarget.create!(label: 'County page', provider: 'facebook', account_ref: '5150',
                                            oauth_access_token: 'user-token')
        http = Dam::FakePublishingHttp.new(
          Dam::FakePublishingHttp.response(body: { 'access_token' => 'page-token' }),
          Dam::FakePublishingHttp.response(body: { 'id' => '778' })
        )

        result = deliver(target, http)

        assert_equal '778', result.external_id
        assert_equal 'https://www.facebook.com/778', result.external_url
        assert_match(%r{/5150\?fields=access_token}, http.call(0).url)
        assert_match(%r{graph-video\.facebook\.com/.+/5150/videos}, http.call(1).url)
        assert_equal 'Bearer page-token', http.call(1).options[:headers]['Authorization']
        assert_equal 'source', http.call(1).options[:file_field]
      end

      test 'a Facebook page the connected account does not administer stops there' do
        target = Dam::PublishTarget.create!(label: 'County page', provider: 'facebook', account_ref: '5150',
                                            oauth_access_token: 'user-token')
        http = Dam::FakePublishingHttp.new(Dam::FakePublishingHttp.response(body: { 'id' => '5150' }))

        error = assert_raises(DeliveryFailed) { deliver(target, http) }
        assert_match(/does not administer/, error.message)
        assert_equal 1, http.calls.size
      end

      test 'a Facebook target with no page ID says so rather than posting nowhere' do
        target = Dam::PublishTarget.create!(label: 'County page', provider: 'facebook', oauth_access_token: 'token')

        error = assert_raises(NotConfigured) { deliver(target, Dam::FakePublishingHttp.new) }
        assert_match(/Page ID/, error.message)
      end

      test 'TikTok asks for an upload address and sends the file in one piece when it fits' do
        target = Dam::PublishTarget.create!(label: 'County TikTok', provider: 'tiktok', oauth_access_token: 'token')
        http = Dam::FakePublishingHttp.new(
          Dam::FakePublishingHttp.response(body: { 'data' => { 'publish_id' => 'pub-1',
                                                               'upload_url' => 'https://upload.tiktok/1' } }),
          Dam::FakePublishingHttp.response,
          Dam::FakePublishingHttp.response(body: { 'data' => { 'status' => 'PROCESSING_UPLOAD' } })
        )

        result = deliver(target, http, privacy: 'SELF_ONLY')

        assert_equal 'pub-1', result.external_id
        source = http.call(0).options[:payload][:source_info]
        assert_equal 'FILE_UPLOAD', source[:source]
        assert_equal 1, source[:total_chunk_count]
        assert_equal 'SELF_ONLY', http.call(0).options[:payload][:post_info][:privacy_level]
        assert_equal 'bytes 0-4/5', http.call(1).options[:headers]['Content-Range']
      end

      test 'a file too large for one piece is cut into chunks TikTok will accept' do
        adapter = Tiktok.new(Dam::Publication.new)

        assert_equal [64.megabytes, 1], adapter.send(:chunking_for, 64.megabytes)
        chunk_size, chunks = adapter.send(:chunking_for, 100.megabytes)
        assert_equal 32.megabytes, chunk_size
        assert_equal 3, chunks
        # The remainder rides on the last chunk rather than becoming a short
        # one of its own, which TikTok refuses.
        last_chunk = 100.megabytes - ((chunks - 1) * chunk_size)
        assert_operator last_chunk, :>=, 5.megabytes
      end

      test 'a custom endpoint can send a description with a link instead of the file' do
        target = Dam::PublishTarget.create!(label: 'Intranet', provider: 'http', body_style: 'json',
                                            endpoint_url: 'https://intranet.example/ingest', http_method: 'PUT')
        http = Dam::FakePublishingHttp.new(Dam::FakePublishingHttp.response(body: { 'identifier' => 'x1' }))

        previous = ENV.fetch('PAPERBOY_PUBLIC_BASE_URL', nil)
        ENV['PAPERBOY_PUBLIC_BASE_URL'] = 'https://paperboy.example/'
        result = deliver(target, http)
        ENV['PAPERBOY_PUBLIC_BASE_URL'] = previous

        assert_equal 'x1', result.external_id
        assert_equal :json_request, http.call(0).verb
        assert_equal Net::HTTP::Put, http.call(0).options[:verb]
        assert_match(%r{\Ahttps://paperboy\.example/dam/media/}, http.call(0).options[:payload]['file_url'])
      end

      private

      def deliver(target, http, **attributes)
        publication = Dam::Publication.create!({ asset: build_asset, publish_target: target, status: 'queued',
                                                 title: 'Board meeting' }.merge(attributes))
        target.adapter_class.new(publication, http: http, access_token: target.oauth_access_token).deliver
      end

      def build_asset
        record = Dam::Asset.new(title: 'Board meeting', media_type: 'video', storage_kind: 'stored',
                                content_type: 'video/mp4', filename: 'board.mp4', storage_location: @location)
        record.file.attach(io: StringIO.new('bytes'), filename: 'board.mp4', content_type: 'video/mp4')
        record.save!
        record
      end
    end
  end
end
