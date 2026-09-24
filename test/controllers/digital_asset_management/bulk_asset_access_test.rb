# frozen_string_literal: true

require 'test_helper'

module DigitalAssetManagement
  # The bulk action bar under the DAM access rules: a selection only ever
  # holds what the person can see, and each action reaches only the part of
  # it they may do that to.
  class BulkAssetAccessTest < ActionController::TestCase
    tests DigitalAssetManagement::BulkAssetsController
    include Dam::ControllerSignIn

    ALL_FEATURES = %w[digital_asset_management:search].freeze

    setup do
      # This suite does not roll back between tests, so the DAM tables are
      # cleared the way the other DAM tests clear theirs.
      [Dam::AccessRuleGrantee, Dam::AccessRule, Dam::Share, Dam::Job, Dam::MetadataValue, Dam::MetadataField,
       ActiveStorage::Attachment, ActiveStorage::Blob, Dam::Asset].each(&:delete_all)
      @video = Dam::Asset.create!(title: 'Board meeting', media_type: 'video')
      @other_video = Dam::Asset.create!(title: 'Budget hearing', media_type: 'video')
      @photo = Dam::Asset.create!(title: 'Board portrait', media_type: 'image')
      request.env['HTTP_REFERER'] = 'http://test.host/digital_asset_management/assets?q=board'
    end

    # A rule left behind would hide assets from every other DAM test.
    teardown { [Dam::AccessRuleGrantee, Dam::AccessRule].each(&:delete_all) }

    test 'the access rules hold back what the person may only look at' do
      @photo.update!(agency_id: 'GSA')
      rule = Dam::AccessRule.create!(name: 'GSA media', agency_id: 'GSA')
      rule.grantees.create!(grantee_type: 'group', group_id: 7)
      sign_in_to_dam(ALL_FEATURES, group_ids: [7])

      post :archive, params: { asset_ids: [@video.id, @photo.id] }

      assert_equal %w[archived active active], statuses
      assert_match(/1 asset skipped: the access rules do not let you archive/, flash[:alert])
    end

    test 'a ticked id outside the rules is not selected at all' do
      @photo.update!(agency_id: 'GSA')
      Dam::AccessRule.create!(name: 'GSA media', agency_id: 'GSA')
      sign_in

      post :archive, params: { asset_ids: [@photo.id] }

      assert_equal %w[active active active], statuses
      assert_match(/Select at least one asset/, flash[:alert])
    end

    private

    def statuses = [@video, @other_video, @photo].map { |asset| asset.reload.status }

    def sign_in = sign_in_to_dam(ALL_FEATURES)
  end
end
