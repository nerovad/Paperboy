# frozen_string_literal: true

require 'test_helper'

module DigitalAssetManagement
  # The bulk action bar: each action reaches every selected asset, "select all"
  # means the whole search rather than the page, and the single-asset grants
  # still hold.
  class BulkAssetsControllerTest < ActionController::TestCase
    tests DigitalAssetManagement::BulkAssetsController
    include ActiveJob::TestHelper
    include Dam::ControllerSignIn

    ALL_FEATURES = %w[digital_asset_management:search digital_asset_management:publish
                      digital_asset_management:collections].freeze

    setup do
      # This suite does not roll back between tests, so the DAM tables are
      # cleared the way the other DAM tests clear theirs.
      [Dam::Publication, Dam::PublishTarget, Dam::Share, Dam::CollectionAsset, Dam::Collection, Dam::Job,
       Dam::MetadataValue, Dam::MetadataField, ActiveStorage::Attachment, ActiveStorage::Blob, Dam::Asset,
       Dam::StorageLocation].each(&:delete_all)
      @location = Dam::StorageLocation.create!(label: 'Library', kind: 'disk')
      @video = build_asset('Board meeting', media_type: 'video')
      @other_video = build_asset('Budget hearing', media_type: 'video')
      @photo = build_asset('Board portrait', media_type: 'image')
      request.env['HTTP_REFERER'] = 'http://test.host/digital_asset_management/assets?q=board'
    end

    test 'nothing selected is turned back before anything happens' do
      sign_in

      post :archive, params: { asset_ids: [] }

      assert_match(/Select at least one asset/, flash[:alert])
      assert_equal 3, Dam::Asset.visible.count
    end

    test 'archiving reaches exactly the ticked assets' do
      sign_in

      post :archive, params: { asset_ids: [@video.id, @photo.id] }

      assert_equal %w[archived active archived], statuses
      assert_redirected_to 'http://test.host/digital_asset_management/assets?q=board'
    end

    test 'select all means every asset the search matches, not only the ticked ones' do
      sign_in

      post :archive, params: { select_all: '1', search: 'q=board', asset_ids: [@video.id] }

      assert_equal %w[archived active archived], statuses
      assert_match(/Archived 2 assets/, flash[:notice])
    end

    test 'sharing makes one share per asset and one Jobs entry' do
      sign_in

      assert_difference -> { Dam::Share.count } => 2, -> { Dam::Job.count } => 1 do
        post :share, params: { asset_ids: [@video.id, @photo.id], recipients: "a@example.com\nb@example.com",
                               permission: 'download' }
      end

      assert_equal [@photo.id, @video.id].sort, Dam::Share.pluck(:subject_id).sort
      assert(Dam::Share.all.all? { |share| share.recipient_list == %w[a@example.com b@example.com] })
      assert_equal '2 assets', Dam::Job.sole.subject_label
    end

    test 'a bulk share with no recipients creates nothing' do
      sign_in

      assert_no_difference -> { Dam::Share.count } do
        post :share, params: { asset_ids: [@video.id], recipients: '' }
      end
      assert_match(/recipient/, flash[:alert])
    end

    test 'metadata is queued with only the fields that were filled in or cleared' do
      %w[campaign rights owner].each do |key|
        Dam::MetadataField.create!(key: key, label: key.titleize, field_type: 'text', active: true)
      end
      sign_in

      post :metadata, params: { asset_ids: [@video.id, @photo.id],
                                metadata: { campaign: 'Summer', rights: '', owner: '', invented: 'x' },
                                clear_metadata: %w[owner] }

      job = Dam::Job.sole
      assert_equal 'metadata', job.job_type
      assert_enqueued_with job: Dam::BulkMetadataJob,
                           args: [job.id, [@video.id, @photo.id].sort, { 'campaign' => 'Summer', 'owner' => '' }]
    end

    test 'publishing queues the assets the target takes and says why it skipped the rest' do
      target = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube', oauth_access_token: 'token')
      sign_in

      assert_difference -> { Dam::Publication.count }, 2 do
        post :publish, params: { asset_ids: [@video.id, @other_video.id, @photo.id], publish_target_id: target.id }
      end

      assert_equal ['Board meeting', 'Budget hearing'], Dam::Publication.order(:title).pluck(:title)
      assert_match(/Publishing 2 assets/, flash[:alert])
      assert_match(/1 skipped: does not take image files/, flash[:alert])
      assert_enqueued_jobs 2, only: Dam::PublishJob
    end

    test 'bulk publishing still needs the publish grant' do
      target = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube', oauth_access_token: 'token')
      sign_in(features: %w[digital_asset_management:search])

      assert_no_difference -> { Dam::Publication.count } do
        post :publish, params: { asset_ids: [@video.id], publish_target_id: target.id }
      end
      assert_redirected_to digital_asset_management_root_path
    end

    test 'adding to a collection skips assets already in it' do
      collection = Dam::Collection.create!(name: 'Meetings')
      Dam::CollectionAsset.create!(collection: collection, asset: @video)
      sign_in

      post :add_to_collection, params: { asset_ids: [@video.id, @other_video.id], collection_id: collection.id }

      assert_equal [@video.id, @other_video.id], collection.collection_assets.order(:position).pluck(:asset_id)
      assert_match(/Added 1 asset to Meetings/, flash[:notice])
    end

    private

    def statuses = [@video, @other_video, @photo].map { |asset| asset.reload.status }

    def build_asset(title, media_type:)
      type = "#{media_type}/#{media_type == 'video' ? 'mp4' : 'jpeg'}"
      record = Dam::Asset.new(title: title, media_type: media_type, storage_kind: 'stored', content_type: type,
                              filename: title, storage_location: @location)
      record.file.attach(io: StringIO.new('bytes'), filename: title, content_type: type)
      record.tap(&:save!)
    end

    def sign_in(features: ALL_FEATURES) = sign_in_to_dam(features)
  end
end
