# frozen_string_literal: true

require 'test_helper'

# The only unauthenticated way out of the library, and the one a provider that
# fetches rather than receives depends on. It has to stay shut except while a
# publish is actually in flight.
class DamMediaControllerTest < ActionController::TestCase
  tests DamMediaController

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
    @asset = build_asset
    @target = Dam::PublishTarget.create!(label: 'County Instagram', provider: 'instagram',
                                         account_ref: '1784', oauth_access_token: 'token')
  end

  test 'a publish in flight serves the file to nobody in particular' do
    publication = publication_with_token(status: 'running')

    get :show, params: { token: publication.public_token }

    assert_response :success
  end

  test 'a token that has never been minted is not a way in' do
    publication_with_token(status: 'running')

    get :show, params: { token: 'made-up' }

    assert_response :not_found
  end

  test 'the link dies an hour after the publish it belonged to' do
    publication = publication_with_token(status: 'succeeded', finished_at: 2.hours.ago)

    get :show, params: { token: publication.public_token }

    assert_response :not_found
  end

  test 'a publication that was never given a token exposes nothing' do
    Dam::Publication.create!(asset: @asset, publish_target: @target, title: 'Board meeting', status: 'running')

    get :show, params: { token: '' }

    assert_response :not_found
  end

  private

  def publication_with_token(**attributes)
    publication = Dam::Publication.create!({ asset: @asset, publish_target: @target,
                                             title: 'Board meeting' }.merge(attributes))
    publication.ensure_public_token!
    publication
  end

  def build_asset
    record = Dam::Asset.new(title: 'Board meeting', media_type: 'image', storage_kind: 'stored',
                            content_type: 'image/jpeg', filename: 'board.jpg', storage_location: @location)
    record.file.attach(io: StringIO.new('bytes'), filename: 'board.jpg', content_type: 'image/jpeg')
    record.save!
    record
  end
end
