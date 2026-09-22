# frozen_string_literal: true

require 'test_helper'

module DigitalAssetManagement
  # Publishing is queued, never done in the request, and the gate holds at the
  # point of asking rather than only on the picker that offered it.
  class PublicationsControllerTest < ActionController::TestCase
    tests DigitalAssetManagement::PublicationsController
    include ActiveJob::TestHelper

    setup do
      # This suite does not roll back between tests, so the DAM tables are
      # cleared the way the other DAM tests clear theirs.
      Dam::Publication.delete_all
      Dam::PublishTarget.delete_all
      Dam::Job.delete_all
      ActiveStorage::Attachment.delete_all
      ActiveStorage::Blob.delete_all
      Dam::Asset.delete_all
      Dam::StorageLocation.delete_all
      @location = Dam::StorageLocation.create!(label: 'Library', kind: 'disk')
      @asset = build_asset
      @target = Dam::PublishTarget.create!(label: 'County YouTube', provider: 'youtube',
                                           oauth_access_token: 'token')
    end

    test 'someone without the publish grant cannot publish by posting to it' do
      sign_in(features: [])

      assert_no_difference -> { Dam::Publication.count } do
        post :create, params: { asset_id: @asset.id, publish_target_id: @target.id, title: 'Board meeting' }
      end
      assert_redirected_to digital_asset_management_root_path
    end

    test 'publishing queues the work and leaves a receipt' do
      sign_in

      assert_difference -> { Dam::Publication.count } => 1, -> { Dam::Job.count } => 1 do
        post :create, params: { asset_id: @asset.id, publish_target_id: @target.id,
                                title: 'Board meeting, June', tags: 'board, minutes', privacy: 'unlisted' }
      end

      publication = Dam::Publication.sole
      assert_equal 'queued', publication.status
      assert_equal 'Board meeting, June', publication.title
      assert_equal %w[board minutes], publication.tag_list
      assert_equal 'unlisted', publication.privacy
      assert_equal '1', publication.requested_by_id
      assert_equal Dam::Job.sole.id, publication.job_id
      assert_enqueued_with job: Dam::PublishJob, args: [publication.id]
    end

    test 'a target that cannot take the asset is refused at the door' do
      image = build_asset(media_type: 'image')
      sign_in

      assert_no_difference -> { Dam::Publication.count } do
        post :create, params: { asset_id: image.id, publish_target_id: @target.id, title: 'A photo' }
      end
      assert_match(/does not take image files/, flash[:alert])
    end

    test 'a disconnected target is refused even though the form offered it' do
      @target.update!(oauth_access_token: nil)
      sign_in

      assert_no_difference -> { Dam::Publication.count } do
        post :create, params: { asset_id: @asset.id, publish_target_id: @target.id, title: 'Board meeting' }
      end
      assert_match(/not connected/, flash[:alert])
    end

    test 'the history lists your own publications and, on request, everyone else' do
      create_publication(requested_by_id: '1', requested_by_name: 'Test User')
      create_publication(requested_by_id: '2002', requested_by_name: 'Someone Else')
      sign_in

      get :index
      assert_response :success
      assert_match(/Test User/, response.body)
      assert_no_match(/Someone Else/, response.body)

      get :index, params: { scope: 'everyone' }
      assert_match(/Someone Else/, response.body)
    end

    test 'a finished publication can be sent again, as a new row' do
      publication = create_publication(requested_by_id: '1', status: 'failed', finished_at: Time.current,
                                       error: 'Timed out')
      sign_in

      assert_difference -> { Dam::Publication.count }, 1 do
        post :retry, params: { id: publication.id }
      end

      assert_predicate publication.reload, :failed?
      assert_equal 'queued', Dam::Publication.order(:id).last.status
    end

    test 'a publish that is already running cannot be cancelled out from under the worker' do
      publication = create_publication(requested_by_id: '1', status: 'running')
      sign_in

      post :cancel, params: { id: publication.id }

      assert_equal 'running', publication.reload.status
      assert_match(/already started/, flash[:alert])
    end

    test 'a queued publish can be cancelled, and takes its job with it' do
      job = Dam::Job.enqueue!(job_type: 'publish', actor: nil, subject: @asset, total_items: 1)
      publication = create_publication(requested_by_id: '1', job_id: job.id)
      sign_in

      post :cancel, params: { id: publication.id }

      assert_equal 'cancelled', publication.reload.status
      assert_equal 'cancelled', job.reload.status
    end

    private

    def create_publication(**attributes)
      Dam::Publication.create!({ asset: @asset, publish_target: @target, status: 'queued',
                                 title: 'Board meeting' }.merge(attributes))
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

    def sign_in(features: %w[digital_asset_management:publish])
      session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                         'first_name' => 'Test', 'last_name' => 'User' }
      feature_keys = features.to_set
      applications = Set['digital_asset_management']
      @controller.define_singleton_method(:current_user_group_names) { Set.new }
      @controller.define_singleton_method(:current_user_group_ids) { [] }
      @controller.define_singleton_method(:current_user_org_chain) { {} }
      @controller.define_singleton_method(:current_user_feature_permission_keys) { feature_keys }
      @controller.define_singleton_method(:current_user_application_permission_keys) { applications }
      @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
    end
  end
end
