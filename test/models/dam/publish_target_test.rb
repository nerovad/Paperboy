# frozen_string_literal: true

require 'test_helper'

module Dam
  class PublishTargetTest < ActiveSupport::TestCase
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

    test 'a key is made from the name and kept unique' do
      target = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube')

      assert_equal 'county_youtube', target.key
      assert_not Dam::PublishTarget.new(label: 'Other', key: 'county_youtube', provider: 'vimeo').valid?
    end

    test 'an unknown provider is refused' do
      target = Dam::PublishTarget.new(label: 'Somewhere', provider: 'myspace')

      assert_not target.valid?
      assert_match(/provider/i, target.errors.full_messages.to_sentence)
    end

    test 'a custom endpoint needs a http address' do
      assert_not Dam::PublishTarget.new(label: 'Intranet', provider: 'http').valid?
      assert_not Dam::PublishTarget.new(label: 'Intranet', provider: 'http', endpoint_url: 'ftp://files').valid?
      assert_predicate Dam::PublishTarget.new(label: 'Intranet', provider: 'http',
                                              endpoint_url: 'https://example.org/ingest'), :valid?
    end

    test 'tokens are not stored in the clear' do
      target = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube',
                                          oauth_access_token: 'ya29-secret')

      stored = Dam::PublishTarget.connection.select_value(
        Dam::PublishTarget.select(:oauth_access_token).where(id: target.id).to_sql
      )

      assert_not_equal 'ya29-secret', stored
      assert_equal 'ya29-secret', target.reload.oauth_access_token
    end

    test 'an OAuth target is closed until it is connected' do
      target = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube')

      assert_equal 'not connected yet', target.refusal_reason
      target.update!(oauth_access_token: 'token')
      assert_nil target.refusal_reason
    end

    test 'a disabled target is closed however well connected it is' do
      target = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube',
                                          oauth_access_token: 'token', enabled: false)

      assert_equal 'disabled', target.refusal_reason
    end

    test 'an expired token that can be renewed is not a disconnection' do
      target = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube',
                                          oauth_access_token: 'token', oauth_refresh_token: 'refresh',
                                          oauth_expires_at: 1.hour.ago)

      assert_predicate target, :token_expired?
      assert_nil target.refusal_reason
    end

    test 'an expired token that cannot be renewed has to be reconnected' do
      target = Dam::PublishTarget.create!(label: 'Department Facebook', provider: 'facebook',
                                          account_ref: '123', oauth_access_token: nil,
                                          oauth_expires_at: 1.hour.ago)

      assert_predicate target, :needs_reconnecting?
      assert_equal 'not connected yet', target.refusal_reason
    end

    test 'a target refuses a media type its service does not take' do
      target = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube',
                                          oauth_access_token: 'token')

      assert_equal 'does not take image files', target.refusal_reason(asset(media_type: 'image'))
      assert_nil target.refusal_reason(asset(media_type: 'video'))
    end

    test 'open_to lists only the targets that would take the asset' do
      open = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube', oauth_access_token: 'token')
      Dam::PublishTarget.create!(label: 'Unconnected', provider: 'vimeo')
      Dam::PublishTarget.create!(label: 'Off', provider: 'youtube', oauth_access_token: 'token', enabled: false)

      assert_equal [open], Dam::PublishTarget.open_to(asset(media_type: 'video'))
    end

    test 'headers are read one per line and anything nameless is skipped' do
      target = Dam::PublishTarget.new(headers: "Authorization: Bearer abc\n\nnonsense\nX-Source: paperboy")

      assert_equal({ 'Authorization' => 'Bearer abc', 'X-Source' => 'paperboy' }, target.header_pairs)
    end

    test 'a refresh that returns no new refresh token keeps the one already held' do
      target = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube',
                                          oauth_refresh_token: 'original')

      target.record_connection!({ access_token: 'new', refresh_token: nil, expires_in: 3599 })

      assert_equal 'original', target.reload.oauth_refresh_token
      assert_equal 'new', target.oauth_access_token
      assert_in_delta 3599, target.oauth_expires_at - Time.current, 5
    end

    private

    def asset(media_type: 'video')
      record = Dam::Asset.new(title: "A #{media_type}", media_type: media_type, storage_kind: 'stored',
                              content_type: "#{media_type}/mp4", filename: "file.#{media_type}",
                              storage_location: @location)
      record.file.attach(io: StringIO.new('bytes'), filename: 'file.mp4', content_type: 'video/mp4')
      record.save!
      record
    end
  end
end
