# frozen_string_literal: true

require 'test_helper'

module Dam
  class PublicationTest < ActiveSupport::TestCase
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
      @target = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube',
                                           oauth_access_token: 'token')
      @asset = build_asset
    end

    test 'what it was is copied at create, so a rename later does not rewrite history' do
      publication = create_publication

      @asset.update!(title: 'Something else')
      @target.update!(label: 'Renamed')

      assert_equal 'Board meeting', publication.reload.asset_title
      assert_equal 'County YouTube', publication.target_label
      assert_equal 'youtube', publication.provider
      assert publication.queued_at
    end

    test 'succeeding records where it landed and stamps the target' do
      publication = create_publication
      publication.start!
      publication.succeed!(external_id: 'abc123', external_url: 'https://www.youtube.com/watch?v=abc123')

      assert_predicate publication, :succeeded?
      assert_equal 'abc123', publication.external_id
      assert publication.finished_at
      assert @target.reload.last_published_at
    end

    test 'failing keeps the reason and stops the run' do
      publication = create_publication
      publication.start!
      publication.fail!('YouTube refused the upload: quotaExceeded', response_code: 403)

      assert_predicate publication, :failed?
      assert_equal 403, publication.response_code
      assert_match(/quotaExceeded/, publication.error)
      assert_not publication.open?
    end

    test 'the public link is live only while the publish is, plus an hour' do
      publication = create_publication
      publication.ensure_public_token!

      assert_predicate publication, :public_link_live?

      publication.update!(status: 'succeeded', finished_at: 5.minutes.ago)
      assert_predicate publication, :public_link_live?

      publication.update!(finished_at: 2.hours.ago)
      assert_not publication.public_link_live?
    end

    test 'a publication without a token is never fetchable' do
      assert_not create_publication.public_link_live?
    end

    test 'the token is minted once and kept' do
      publication = create_publication
      token = publication.ensure_public_token!

      assert_equal token, publication.ensure_public_token!
      assert_equal 1, Dam::Publication.where(public_token: token).count
    end

    test 'a retry is a new row, so the failure it followed stays readable' do
      failed = create_publication
      failed.start!
      failed.fail!('Timed out')

      again = failed.duplicate_for_retry
      assert again.save
      assert_equal 'queued', again.status
      assert_equal failed.title, again.title
      assert_not_equal failed.id, again.id
      assert_predicate failed.reload, :failed?
    end

    test 'tags are typed as a list and stored as one string' do
      publication = create_publication
      publication.tag_list = ['board ', '', ' meeting']

      assert_equal 'board, meeting', publication.tags
      assert_equal %w[board meeting], publication.tag_list
    end

    test 'in_state ignores anything that is not a status' do
      queued = create_publication

      assert_equal [queued], Dam::Publication.in_state('queued').to_a
      assert_empty Dam::Publication.in_state('failed').to_a
      assert_equal [queued], Dam::Publication.in_state('nonsense').to_a
    end

    private

    def create_publication
      Dam::Publication.create!(asset: @asset, publish_target: @target, title: @asset.title, status: 'queued')
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
