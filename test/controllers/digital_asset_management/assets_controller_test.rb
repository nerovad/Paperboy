# frozen_string_literal: true

require 'test_helper'

module DigitalAssetManagement
  # The Publish panel on an asset: who sees it, and what it offers them.
  class AssetsControllerTest < ActionController::TestCase
    tests DigitalAssetManagement::AssetsController

    setup do
      # This suite does not roll back between tests, so the DAM tables are
      # cleared the way the other DAM tests clear theirs.
      Dam::Publication.delete_all
      Dam::PublishTarget.delete_all
      Dam::RecentView.delete_all
      ActiveStorage::Attachment.delete_all
      ActiveStorage::Blob.delete_all
      Dam::Asset.delete_all
      Dam::StorageLocation.delete_all
      @location = Dam::StorageLocation.create!(label: 'Library', kind: 'disk')
      @asset = build_asset
    end

    test 'without the publish grant the asset page offers no publishing at all' do
      Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube', oauth_access_token: 'token')
      sign_in(features: [])

      get :show, params: { id: @asset.id }

      assert_response :success
      assert_no_match(/Send to/, response.body)
    end

    test 'the panel offers the targets that would take this asset' do
      Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube', oauth_access_token: 'token')
      sign_in

      get :show, params: { id: @asset.id }

      assert_response :success
      assert_match(/County YouTube/, response.body)
      assert_match(/Send to/, response.body)
    end

    test 'a target that will not take this asset is shown with its reason rather than hidden' do
      Dam::PublishTarget.create!(label: 'County Vimeo', provider: 'vimeo')
      sign_in

      get :show, params: { id: build_asset(media_type: 'image').id }

      assert_response :success
      assert_match(/County Vimeo \(not connected yet\)/, response.body)
    end

    test 'what has already been published from this asset is listed on it' do
      target = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube', oauth_access_token: 'token')
      Dam::Publication.create!(asset: @asset, publish_target: target, title: 'Board meeting',
                               status: 'succeeded', external_url: 'https://www.youtube.com/watch?v=abc')
      sign_in

      get :show, params: { id: @asset.id }

      assert_match(/Already published/, response.body)
      assert_match(%r{youtube\.com/watch\?v=abc}, response.body)
    end

    test 'the library carries the bulk action bar, with Publish only for the publish grant' do
      Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube', oauth_access_token: 'token')
      sign_in(features: %w[digital_asset_management:search digital_asset_management:publish])

      get :index, params: { q: 'board' }

      assert_response :success
      assert_match(/data-controller="dam-selection"/, response.body)
      assert_match(/data-dam-selection-search-value="q=board"/, response.body)
      assert_match(/value="#{@asset.id}"[^>]*data-dam-selection-target="checkbox"/, response.body)
      assert_match(/data-dam-selection-modal-param="publish"/, response.body)
      assert_match(/data-modal="share"/, response.body)

      sign_in(features: %w[digital_asset_management:search])
      get :index
      assert_no_match(/data-dam-selection-modal-param="publish"/, response.body)
    end

    private

    def build_asset(media_type: 'video')
      extension = media_type == 'video' ? 'mp4' : 'jpg'
      record = Dam::Asset.new(title: "Board meeting #{media_type}", media_type: media_type, storage_kind: 'stored',
                              content_type: "#{media_type}/#{extension}", filename: "board.#{extension}",
                              storage_location: @location)
      record.file.attach(io: StringIO.new('bytes'), filename: "board.#{extension}",
                         content_type: "#{media_type}/#{extension}")
      record.save!
      record
    end

    def sign_in(features: %w[digital_asset_management:publish])
      session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                         'first_name' => 'Test', 'last_name' => 'User' }
      feature_keys = features.to_set
      applications = Set['digital_asset_management']
      @controller.define_singleton_method(:current_user_group_names) { Set.new }
      @controller.define_singleton_method(:current_user_feature_permission_keys) { feature_keys }
      @controller.define_singleton_method(:current_user_application_permission_keys) { applications }
      @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
    end
  end
end
