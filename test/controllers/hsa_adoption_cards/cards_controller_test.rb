# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module HsaAdoptionCards
  class CardsControllerTest < ActionController::TestCase
    tests HsaAdoptionCards::CardsController

    MANAGED = [CardFile::WINDOWS_ENV, CardFile::LINUX_ENV].freeze

    setup do
      @old_env = MANAGED.to_h { |key| [key, ENV.fetch(key, nil)] }
      @mount = Dir.mktmpdir
      ENV[CardFile::WINDOWS_ENV] = '\\\\gsa-scan01\\hsa\\Adoption_Cards'
      ENV[CardFile::LINUX_ENV] = @mount
      FileUtils.mkdir_p(File.join(@mount, 'Child'))
      File.write(File.join(@mount, 'Child', 'card.pdf'), '%PDF-1.7 test')

      session[:user] = { 'email' => 'searcher@example.com', 'employee_id' => 42 }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    teardown do
      @old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      FileUtils.remove_entry(@mount) if @mount && Dir.exist?(@mount)
    end

    test 'a card inside the share streams inline as a PDF' do
      get :pdf, params: { path: '\\\\gsa-scan01\\hsa\\Adoption_Cards\\Child\\card.pdf' }

      assert_response :success
      assert_equal 'application/pdf', response.media_type
      assert_match(/inline/, response.headers['Content-Disposition'])
      assert_equal '%PDF-1.7 test', response.body
    end

    test 'a path outside the share is not found' do
      get :pdf, params: { path: '\\\\gsa-scan01\\hsa\\Somewhere\\else.pdf' }

      assert_response :not_found
      assert_match(/outside the scanned-cards folder/, response.body)
    end

    test 'a signed-out visitor is sent away' do
      session[:user] = nil
      get :pdf, params: { path: '\\\\gsa-scan01\\hsa\\Adoption_Cards\\Child\\card.pdf' }
      assert_redirected_to root_path
    end

    test 'holding the app but neither search nor browse is refused' do
      @controller.define_singleton_method(:current_user_group_names) { Set['staff'] }
      @controller.define_singleton_method(:current_user_application_permission_keys) { ['hsa_adoption_cards'] }
      @controller.define_singleton_method(:current_user_feature_permission_keys) { [] }
      @controller.define_singleton_method(:current_user_dropdown_permissions) { [] }

      get :pdf, params: { path: '\\\\gsa-scan01\\hsa\\Adoption_Cards\\Child\\card.pdf' }
      assert_redirected_to hsa_adoption_cards_root_path
    end
  end
end
