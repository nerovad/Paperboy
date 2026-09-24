# frozen_string_literal: true

require 'test_helper'

module DigitalAssetManagement
  # The one door an asset's bytes go through: a token only the person it was
  # issued to can spend.
  class FilesControllerTest < ActionController::TestCase
    tests DigitalAssetManagement::FilesController

    setup do
      [ActiveStorage::Attachment, ActiveStorage::Blob, Dam::Asset].each(&:delete_all)
      @asset = Dam::Asset.new(title: 'Photo', media_type: 'image', content_type: 'image/jpeg', filename: 'photo.jpg')
      @asset.file.attach(io: StringIO.new('bytes'), filename: 'photo.jpg', content_type: 'image/jpeg')
      @asset.save!
    end

    test 'the person it was issued to is sent on to the file' do
      sign_in_as(1)

      get :show, params: { token: Dam::FileToken.generate(@asset, :file, employee_id: 1) }

      assert_response :redirect
      assert_match %r{/rails/active_storage/disk/}, response.location
    end

    test 'anyone else gets nothing' do
      sign_in_as(2)

      get :show, params: { token: Dam::FileToken.generate(@asset, :file, employee_id: 1) }

      assert_response :not_found
    end

    test 'nobody signed in gets nothing' do
      get :show, params: { token: Dam::FileToken.generate(@asset, :file, employee_id: 1) }

      assert_response :not_found
    end

    test 'a forged or expired token gets nothing' do
      sign_in_as(1)
      token = Dam::FileToken.generate(@asset, :file, employee_id: 1)

      get :show, params: { token: "#{token}x" }

      assert_response :not_found

      travel Dam::FileToken::LIFETIME + 1.minute do
        get :show, params: { token: token }

        assert_response :not_found
      end
    end

    private

    def sign_in_as(employee_id)
      session[:user] = { 'employee_id' => employee_id, 'email' => 'employee@example.com',
                         'first_name' => 'Test', 'last_name' => 'User' }
    end
  end
end
