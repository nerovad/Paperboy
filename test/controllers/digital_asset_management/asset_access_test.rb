# frozen_string_literal: true

require 'test_helper'

module DigitalAssetManagement
  # The DAM access rules as someone browsing the library meets them: what is
  # listed, what opens, and which buttons each person is offered.
  class AssetAccessTest < ActionController::TestCase
    tests DigitalAssetManagement::AssetsController
    include Dam::ControllerSignIn

    MEMBERS = 7
    FEATURES = %w[digital_asset_management:search].freeze

    setup do
      # This suite does not roll back between tests, so the DAM tables are
      # cleared the way the other DAM tests clear theirs.
      [Dam::AccessRuleGrantee, Dam::AccessRule, Dam::Publication, Dam::PublishTarget, Dam::RecentView,
       Dam::Share, Dam::Job, Dam::MetadataValue, Dam::MetadataField, ActiveStorage::Attachment,
       ActiveStorage::Blob, Dam::Asset, Dam::StorageLocation].each(&:delete_all)
      @location = Dam::StorageLocation.create!(label: 'Library', kind: 'disk')
      @restricted = build_asset('Restricted briefing', agency_id: 'GSA')
      @open = build_asset('Open briefing')
      @rule = Dam::AccessRule.create!(name: 'GSA media', agency_id: 'GSA')
      @rule.grantees.create!(grantee_type: 'group', group_id: MEMBERS)
    end

    # A rule left behind would hide assets from every other DAM test.
    teardown { [Dam::AccessRuleGrantee, Dam::AccessRule].each(&:delete_all) }

    test 'the library lists only what the searcher may see' do
      sign_in_to_dam(FEATURES)

      get :index, params: { q: 'briefing' }

      assert_response :success
      assert_match 'Open briefing', response.body
      assert_no_match 'Restricted briefing', response.body
    end

    test 'the people a rule names find its assets' do
      sign_in_to_dam(FEATURES, group_ids: [MEMBERS])

      get :index, params: { q: 'briefing' }

      assert_match 'Restricted briefing', response.body
    end

    test 'an asset outside the rules reads as not found' do
      sign_in_to_dam(FEATURES)

      assert_raises(ActiveRecord::RecordNotFound) { get :show, params: { id: @restricted.id } }
    end

    test 'view only means no download, edit or share' do
      sign_in_to_dam(FEATURES, group_ids: [MEMBERS])

      get :show, params: { id: @restricted.id }

      assert_response :success
      assert_no_match(/>Download</, response.body)
      assert_no_match(/>Edit</, response.body)
      assert_no_match(/Create share/, response.body)
    end

    test 'the actions refuse what the page did not offer' do
      sign_in_to_dam(FEATURES, group_ids: [MEMBERS])

      patch :update, params: { id: @restricted.id, asset: { title: 'Renamed' } }

      assert_redirected_to digital_asset_management_asset_path(@restricted)
      assert_match(/do not let you edit/, flash[:alert])
      assert_equal 'Restricted briefing', @restricted.reload.title

      post :share, params: { id: @restricted.id, recipients: 'someone@example.com' }

      assert_match(/do not let you share/, flash[:alert])
      assert_equal 0, Dam::Share.count
    end

    test 'a rule that allows download offers it' do
      @rule.update!(can_download: true, can_edit: true)
      sign_in_to_dam(FEATURES, group_ids: [MEMBERS])

      get :show, params: { id: @restricted.id }

      assert_match(/>Download</, response.body)
      assert_match(/>Edit</, response.body)
    end

    test 'files are linked through tokens, never standing blob URLs' do
      sign_in_to_dam(FEATURES)

      get :index, params: { q: 'briefing' }

      assert_no_match(%r{/rails/active_storage/}, response.body)
    end

    private

    def build_asset(title, **attributes)
      record = Dam::Asset.new(title: title, media_type: 'image', storage_kind: 'stored', content_type: 'image/jpeg',
                              filename: "#{title}.jpg", storage_location: @location, **attributes)
      record.file.attach(io: StringIO.new('bytes'), filename: "#{title}.jpg", content_type: 'image/jpeg')
      record.tap(&:save!)
    end
  end
end
