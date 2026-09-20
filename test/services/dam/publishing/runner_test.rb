# frozen_string_literal: true

require 'test_helper'
require_relative '../../../support/dam/fake_publishing_http'

module Dam
  module Publishing
    class RunnerTest < ActiveSupport::TestCase
      setup do
        # This suite does not roll back between tests, so the DAM tables are
        # cleared the way the other model tests clear theirs.
        Dam::Publication.delete_all
        Dam::PublishTarget.delete_all
        Dam::Job.delete_all
        ActiveStorage::Attachment.delete_all
        ActiveStorage::Blob.delete_all
        Dam::Asset.delete_all
        Dam::StorageLocation.delete_all
        @location = Dam::StorageLocation.create!(label: 'Library', kind: 'disk')
        @asset = build_asset
      end

      test 'a YouTube publish opens a session, sends the file and records the link' do
        target = youtube_target
        http = Dam::FakePublishingHttp.new(
          Dam::FakePublishingHttp.response(headers: { 'location' => ['https://upload.example/session'] }),
          Dam::FakePublishingHttp.response(body: { 'id' => 'abc123' })
        )

        publication = publish(target, http)

        assert_predicate publication, :succeeded?
        assert_equal 'abc123', publication.external_id
        assert_equal 'https://www.youtube.com/watch?v=abc123', publication.external_url
        assert_equal 'https://upload.example/session', http.call(1).url
        assert_equal 'Bearer ya29-token', http.call(0).options[:headers]['Authorization']
        assert_match(/Done/, publication.log)
      end

      test 'the video is described to YouTube before a byte is sent' do
        http = Dam::FakePublishingHttp.new(
          Dam::FakePublishingHttp.response(headers: { 'location' => ['https://upload.example/session'] }),
          Dam::FakePublishingHttp.response(body: { 'id' => 'abc123' })
        )

        publish(youtube_target, http, title: 'Board meeting, June', tags: 'board, minutes', privacy: 'unlisted')

        payload = http.call(0).options[:payload]
        assert_equal 'Board meeting, June', payload[:snippet][:title]
        assert_equal %w[board minutes], payload[:snippet][:tags]
        assert_equal 'unlisted', payload[:status][:privacyStatus]
        assert_equal false, payload[:status][:selfDeclaredMadeForKids]
      end

      test 'a refusal is recorded on the publication rather than raised' do
        http = Dam::FakePublishingHttp.new(
          Dam::FakePublishingHttp.response(code: 403, body: { 'error' => { 'message' => 'quotaExceeded' } })
        )

        publication = publish(youtube_target, http)

        assert_predicate publication, :failed?
        assert_equal 403, publication.response_code
        assert_match(/quotaExceeded/, publication.error)
        assert_equal 1, http.calls.size
      end

      test 'a session that comes back without an upload address is a failure, not a silent success' do
        http = Dam::FakePublishingHttp.new(Dam::FakePublishingHttp.response)

        publication = publish(youtube_target, http)

        assert_predicate publication, :failed?
        assert_match(/no upload session/i, publication.error)
      end

      test 'a target that cannot take the asset never opens a connection' do
        target = youtube_target
        target.update!(enabled: false)
        http = Dam::FakePublishingHttp.new

        publication = publish(target, http)

        assert_predicate publication, :failed?
        assert_match(/disabled/, publication.error)
        assert_empty http.calls
      end

      test 'the job feed entry follows the publication' do
        job = Dam::Job.enqueue!(job_type: 'publish', actor: nil, subject: @asset, total_items: 1)
        http = Dam::FakePublishingHttp.new(
          Dam::FakePublishingHttp.response(headers: { 'location' => ['https://upload.example/session'] }),
          Dam::FakePublishingHttp.response(body: { 'id' => 'abc123' })
        )

        publication = publication_for(youtube_target)
        publication.update!(job_id: job.id)
        Runner.new(publication, http: http).call

        assert_equal 'succeeded', job.reload.status
        assert_match(/youtube.com/, job.log)
      end

      test 'an expired token is renewed before the upload rather than after it fails' do
        target = youtube_target
        target.update!(oauth_refresh_token: 'refresh', oauth_expires_at: 1.minute.from_now)
        http = Dam::FakePublishingHttp.new(
          Dam::FakePublishingHttp.response(body: { 'access_token' => 'fresh-token', 'expires_in' => 3599 }),
          Dam::FakePublishingHttp.response(headers: { 'location' => ['https://upload.example/session'] }),
          Dam::FakePublishingHttp.response(body: { 'id' => 'abc123' })
        )

        with_client_env('PUBLISH_YOUTUBE_CLIENT_ID' => 'id', 'PUBLISH_YOUTUBE_CLIENT_SECRET' => 'secret') do
          publication = publish(target, http)

          assert_predicate publication, :succeeded?
        end

        assert_equal 'https://oauth2.googleapis.com/token', http.call(0).url
        assert_equal 'refresh_token', http.call(0).options[:fields]['grant_type']
        assert_equal 'Bearer fresh-token', http.call(1).options[:headers]['Authorization']
        assert_equal 'fresh-token', target.reload.oauth_access_token
      end

      test 'a custom endpoint is sent the file with the headers the target carries' do
        target = Dam::PublishTarget.create!(label: 'Intranet', provider: 'http',
                                            endpoint_url: 'https://intranet.example/ingest',
                                            headers: 'X-Token: abc123', file_field: 'upload')
        http = Dam::FakePublishingHttp.new(Dam::FakePublishingHttp.response(body: { 'id' => '77', 'url' => 'https://intranet.example/m/77' }))

        publication = publish(target, http, title: 'Board meeting')

        assert_predicate publication, :succeeded?
        assert_equal 'https://intranet.example/m/77', publication.external_url
        call = http.call(0)
        assert_equal :post_multipart, call.verb
        assert_equal 'upload', call.options[:file_field]
        assert_equal 'abc123', call.options[:headers]['X-Token']
        assert_equal 'Board meeting', call.options[:fields]['title']
      end

      test 'a provider that fetches the file needs a public address before it will try' do
        target = Dam::PublishTarget.create!(label: 'County Instagram', provider: 'instagram',
                                            account_ref: '1784', oauth_access_token: 'token')
        http = Dam::FakePublishingHttp.new

        publication = with_public_base(nil) { publish(target, http, media_type: 'image') }

        assert_predicate publication, :failed?
        assert_match(/PAPERBOY_PUBLIC_BASE_URL/, publication.error)
      end

      test 'an image goes to Instagram as a container that is then published' do
        target = Dam::PublishTarget.create!(label: 'County Instagram', provider: 'instagram',
                                            account_ref: '1784', oauth_access_token: 'token')
        http = Dam::FakePublishingHttp.new(
          Dam::FakePublishingHttp.response(body: { 'id' => 'container-1' }),
          Dam::FakePublishingHttp.response(body: { 'id' => 'media-9' }),
          Dam::FakePublishingHttp.response(body: { 'permalink' => 'https://www.instagram.com/p/xyz/' })
        )

        publication = with_public_base('https://paperboy.example') { publish(target, http, media_type: 'image') }

        assert_predicate publication, :succeeded?
        assert_equal 'media-9', publication.external_id
        assert_equal 'https://www.instagram.com/p/xyz/', publication.external_url
        assert_match(%r{https://paperboy\.example/dam/media/}, http.call(0).options[:fields]['image_url'])
        assert_equal 'container-1', http.call(1).options[:fields]['creation_id']
      end

      private

      def youtube_target
        Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube',
                                   oauth_access_token: 'ya29-token', oauth_expires_at: 1.hour.from_now)
      end

      def publication_for(target, media_type: 'video', **attributes)
        asset = media_type == 'video' ? @asset : build_asset(media_type: media_type)
        Dam::Publication.create!({ asset: asset, publish_target: target, status: 'queued',
                                   title: asset.title }.merge(attributes))
      end

      def publish(target, http, media_type: 'video', tags: nil, **attributes)
        publication = publication_for(target, media_type: media_type, **attributes)
        publication.tag_list = tags.to_s.split(',') if tags
        publication.save!
        Runner.new(publication, http: http).call
        publication.reload
      end

      def build_asset(media_type: 'video')
        extension = media_type == 'video' ? 'mp4' : 'jpg'
        record = Dam::Asset.new(title: 'Board meeting', media_type: media_type, storage_kind: 'stored',
                                content_type: "#{media_type}/#{extension}", filename: "board.#{extension}",
                                storage_location: @location)
        record.file.attach(io: StringIO.new('bytes'), filename: "board.#{extension}",
                           content_type: "#{media_type}/#{extension}")
        record.save!
        record
      end

      def with_client_env(values)
        previous = values.keys.index_with { |key| ENV.fetch(key, nil) }
        values.each { |key, value| ENV[key] = value }
        yield
      ensure
        previous.each { |key, value| ENV[key] = value }
      end

      def with_public_base(value)
        previous = ENV.fetch('PAPERBOY_PUBLIC_BASE_URL', nil)
        ENV['PAPERBOY_PUBLIC_BASE_URL'] = value
        yield
      ensure
        ENV['PAPERBOY_PUBLIC_BASE_URL'] = previous
      end
    end
  end
end
