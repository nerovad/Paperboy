# frozen_string_literal: true

require 'test_helper'

module HsaAdoptionCards
  class MaintenanceControllerTest < ActionController::TestCase
    tests HsaAdoptionCards::MaintenanceController

    setup do
      session[:user] = { 'email' => 'keyer@example.com', 'employee_id' => 42, 'first_name' => 'Sam' }
    end

    def grant_features(*keys)
      @controller.define_singleton_method(:current_user_group_names) { Set['staff'] }
      @controller.define_singleton_method(:current_user_application_permission_keys) { ['hsa_adoption_cards'] }
      @controller.define_singleton_method(:current_user_feature_permission_keys) { keys }
      @controller.define_singleton_method(:current_user_dropdown_permissions) { [] }
    end

    # Minitest's stub is not available in this suite, so the class method is
    # swapped by hand and always put back.
    def with_rebuild(fake)
      original = CaseGroupRebuild.method(:call)
      CaseGroupRebuild.define_singleton_method(:call) { |margin: nil| fake.call(margin: margin) }
      yield
    ensure
      CaseGroupRebuild.define_singleton_method(:call, original)
    end

    test 'search and browse alone do not open maintenance' do
      grant_features('hsa_adoption_cards:search', 'hsa_adoption_cards:browse')
      get :index
      assert_redirected_to hsa_adoption_cards_root_path
    end

    test 'the maintenance feature shows the rebuild form behind a confirm' do
      grant_features('hsa_adoption_cards:maintenance')
      get :index

      assert_response :success
      assert_select 'form[action=?][data-turbo-confirm]', hsa_adoption_cards_maintenance_rebuild_path
      assert_select 'input[name=ambiguity_margin][value="5"]'
      assert_select 'button.btn.warning', text: 'Rebuild case groups'
      assert_select '.hsa-adoption-cards-sidebar a.nav-link', text: 'Maintenance'
    end

    test 'a rebuild shows the counts by status' do
      grant_features('hsa_adoption_cards:maintenance')
      captured = nil
      fake = lambda do |margin:|
        captured = margin
        CaseGroupRebuild::Result.new(margin: 8, counts: { 'AUTO' => 4, 'REVIEW' => 1 }, total: 5)
      end

      with_rebuild(fake) { post :rebuild, params: { ambiguity_margin: '8' } }

      assert_response :success
      assert_equal '8', captured
      assert_select '.hsa-ac-counts td', text: '4'
      assert_select '.hsa-ac-badge.is-REVIEW', text: 'REVIEW'
      assert_match(/5 groups/, flash[:notice])
    end

    test 'a refusal is shown on the page rather than raised' do
      grant_features('hsa_adoption_cards:maintenance')
      refusal = AccessDenied.new('Your account is not authorised.', detail: 'EXECUTE denied')

      with_rebuild(->(**) { raise refusal }) { post :rebuild, params: { ambiguity_margin: '5' } }

      assert_response :unprocessable_entity
      assert_select '.hsa-ac-error', text: /not authorised/
      assert_select '.hsa-ac-error .hsa-ac-mono', text: 'EXECUTE denied'
    end
  end
end
