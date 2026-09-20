# frozen_string_literal: true

require 'test_helper'

module DigitalAssetManagement
  # Setting up somewhere to publish is administrative — its own grant, apart
  # from the one that lets somebody send a video to a channel already set up.
  class PublishTargetsControllerTest < ActionController::TestCase
    tests DigitalAssetManagement::PublishTargetsController

    setup do
      # This suite does not roll back between tests, so the DAM tables are
      # cleared the way the other DAM tests clear theirs.
      Dam::Publication.delete_all
      Dam::PublishTarget.delete_all
      ActiveStorage::Attachment.delete_all
      ActiveStorage::Blob.delete_all
      Dam::Asset.delete_all
      Dam::StorageLocation.delete_all
      @location = Dam::StorageLocation.create!(label: 'Library', kind: 'disk')
    end

    test 'the publish grant alone does not let somebody connect an account' do
      sign_in(features: %w[digital_asset_management:publish])

      get :index

      assert_redirected_to digital_asset_management_root_path
    end

    test 'the setup screens render' do
      target = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube')
      sign_in

      get :index
      assert_response :success
      assert_match(/County YouTube/, response.body)

      get :new
      assert_response :success

      get :show, params: { id: target.id }
      assert_response :success
      # Nothing to connect with, so the screen says what .env is missing
      # rather than offering a button that could only fail.
      assert_match(/PUBLISH_YOUTUBE_CLIENT_ID/, response.body)

      get :edit, params: { id: target.id }
      assert_response :success
    end

    test 'a custom endpoint target keeps its headers and is ready at once' do
      sign_in

      post :create, params: { publish_target: { label: 'Intranet', provider: 'http',
                                                endpoint_url: 'https://intranet.example/ingest',
                                                headers: 'X-Token: abc123', file_field: 'upload' } }

      target = Dam::PublishTarget.sole
      assert_redirected_to digital_asset_management_publish_target_path(target)
      assert_equal({ 'X-Token' => 'abc123' }, target.header_pairs)
      assert_nil target.refusal_reason
    end

    test 'an endpoint that is not a http address is refused' do
      sign_in

      assert_no_difference -> { Dam::PublishTarget.count } do
        post :create, params: { publish_target: { label: 'Intranet', provider: 'http',
                                                  endpoint_url: 'file:///etc/passwd' } }
      end
      assert_response :unprocessable_entity
    end

    test 'a target that has published something is disabled rather than deleted' do
      target = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube', oauth_access_token: 'token')
      Dam::Publication.create!(asset: build_asset, publish_target: target, title: 'Board meeting', status: 'succeeded')
      sign_in

      assert_no_difference -> { Dam::PublishTarget.count } do
        delete :destroy, params: { id: target.id }
      end
      assert_match(/cannot be deleted/, flash[:alert])

      patch :toggle, params: { id: target.id }
      assert_not target.reload.enabled?
    end

    test 'disconnecting forgets the tokens without touching what was published' do
      target = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube',
                                          oauth_access_token: 'token', oauth_refresh_token: 'refresh',
                                          connected_at: Time.current, connected_by_name: 'Test User')
      publication = Dam::Publication.create!(asset: build_asset, publish_target: target,
                                             title: 'Board meeting', status: 'succeeded')
      sign_in

      delete :disconnect, params: { id: target.id }

      target.reload
      assert_nil target.oauth_access_token
      assert_nil target.oauth_refresh_token
      assert_nil target.connected_at
      assert_predicate target, :needs_reconnecting?
      assert_predicate publication.reload, :succeeded?
    end

    private

    def build_asset
      record = Dam::Asset.new(title: 'Board meeting', media_type: 'video', storage_kind: 'stored',
                              content_type: 'video/mp4', filename: 'board.mp4', storage_location: @location)
      record.file.attach(io: StringIO.new('bytes'), filename: 'board.mp4', content_type: 'video/mp4')
      record.save!
      record
    end

    def sign_in(features: %w[digital_asset_management:publish_targets])
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
