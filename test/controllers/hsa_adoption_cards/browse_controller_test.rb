# frozen_string_literal: true

require 'test_helper'

module HsaAdoptionCards
  class BrowseControllerTest < ActionController::TestCase
    tests HsaAdoptionCards::BrowseController

    setup do
      session[:user] = { 'email' => 'browser@example.com', 'employee_id' => 42, 'first_name' => 'Sam' }
    end

    def grant_features(*keys)
      @controller.define_singleton_method(:current_user_group_names) { Set['staff'] }
      @controller.define_singleton_method(:current_user_application_permission_keys) { ['hsa_adoption_cards'] }
      @controller.define_singleton_method(:current_user_feature_permission_keys) { keys }
      @controller.define_singleton_method(:current_user_dropdown_permissions) { [] }
    end

    test 'holding the app without the browse feature lands on the app home' do
      grant_features('hsa_adoption_cards:search')
      get :index
      assert_redirected_to hsa_adoption_cards_root_path
    end

    test 'the browse feature opens the page with its filters and pager' do
      grant_features('hsa_adoption_cards:browse')
      get :index

      assert_response :success
      assert_select '[data-controller=hsa-adoption-cards][data-hsa-adoption-cards-mode-value=browse]'
      assert_select 'select[data-hsa-adoption-cards-target=browseStatus] option', 6
      assert_select 'button.btn', text: /Prev/
      assert_select '.pb-modal.hsa-ac-viewer[role=dialog]'
    end

    test 'the sidebar shows only the screens the person holds' do
      grant_features('hsa_adoption_cards:browse')
      get :index

      assert_select '.hsa-adoption-cards-sidebar a.nav-link', text: 'Browse'
      assert_select '.hsa-adoption-cards-sidebar a.nav-link', text: 'Search', count: 0
    end
  end
end
