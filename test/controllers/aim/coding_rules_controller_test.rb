# frozen_string_literal: true

require 'test_helper'

module Aim
  # The Lookups screens (item b.3): the rules, editing one with the COA
  # checking, Save anyway, Retire; loading a file, applying it, undoing it.
  module LookupsTestSession
    def sign_in_admin
      session[:user] = { 'email' => 'fiscal@example.com', 'employee_id' => 42 }
      @controller.define_singleton_method(:current_user_group_names) { Set['aim_admin'] }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end

    def sign_in_nobody
      session[:user] = { 'email' => 'someone@example.com', 'employee_id' => 43 }
      @controller.define_singleton_method(:current_user_group_names) { Set[] }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end

    def rule(**attrs)
      Aim::CodingRule.create!({ agency: 'GSA', budget_unit: '4641', vendor_name: 'ACME', encumbrance: 'BDO_46402024072600000001_1',
                                object_code: '2162', effective_from: Date.new(2024, 7, 1) }.merge(attrs))
    end
  end

  class CodingRulesControllerTest < ActionController::TestCase
    include LookupsTestSession

    tests Aim::CodingRulesController

    setup { sign_in_admin }

    test 'lists the rules for an agency, and the BUs with none' do
      rule
      get :index, params: { agency: 'GSA' }

      assert_response :success
      assert_select 'a', text: 'ACME'
      assert_includes @controller.instance_variable_get(:@units_without_rules), '4601'
    end

    test 'someone who is neither Fiscal nor an admin is turned away' do
      sign_in_nobody
      get :index

      assert_redirected_to aim_root_path
    end

    test 'a valid edit is saved with its history; the COA refuses a bad code until Save anyway' do
      r = rule
      patch :update, params: { id: r.id, coding_rule: { object_code: '2199', encumbrance: 'do_4640X' } }
      assert_redirected_to aim_coding_rule_path(r)
      assert_equal %w[2199 DO 4640X], [r.reload.object_code, r.encumbrance_type, r.encumbrance_number]
      assert_equal %w[object_code encumbrance_type encumbrance_number].sort, r.changes_made.where(kind: 'updated').pluck(:field).sort

      patch :update, params: { id: r.id, coding_rule: { object_code: '99999' } }
      assert_response :unprocessable_content
      assert_equal '2199', r.reload.object_code

      patch :update, params: { id: r.id, save_anyway: '1', coding_rule: { object_code: '99999' } }
      assert_equal '99999', r.reload.object_code
      assert_match(/99999.*not in the COA/, r.warnings)
    end

    test 'retire ends the rule yesterday' do
      r = rule
      patch :retire, params: { id: r.id }

      assert_equal Date.current - 1, r.reload.effective_until
      assert_not r.in_effect?
      assert_equal 'retired', r.changes_made.last.kind
    end
  end

  class CodingImportsControllerTest < ActionController::TestCase
    include LookupsTestSession

    tests Aim::CodingImportsController

    HEADER = 'Vendor Name,AIM Unique Identifier,Fiscal Unique Identifier,Fund,Department,' \
             '"Encumbrance Doc (BDO, DO, etc)",Budget Unit,Object,Activity,Function,Program,Phase,Task,' \
             'Approver Name,Fusion Queue,Keywords'

    setup { sign_in_admin }

    def upload(*lines)
      Rack::Test::UploadedFile.new(StringIO.new(([HEADER] + lines).join("\n")), 'text/csv', original_filename: 'Fleet.csv')
    end

    ROWS = ['FAST SIGNS,,,,,BDO_46402023072600000005_1,4641,2162,GATV,GFUN,INDIRECT,,,,,',
            'Bad Object,,,,,BDO_46402023072600000006_1,4641,22304,GATV,GFUN,INDIRECT,,,,,'].freeze

    # A previewed import, as create leaves it (a second request after a
    # multipart post trips Rack in a controller test, so the flow is split).
    def previewed_import
      import = Aim::CodingImport.new(agency: 'GSA', file_name: 'Fleet.csv', imported_by: 'fiscal@example.com',
                                     effective_option: 'today', status: 'previewed', file_content: ([HEADER] + ROWS).join("\n"))
      import.with_file { |path| import.report = Aim::LookupImport.new(path, agency: 'GSA', effective: 'today').report }
      import.save!
      import
    end

    test 'a file is read and reported first; nothing is loaded' do
      post :create, params: { file: upload(*ROWS), agency: 'GSA', effective: 'today' }

      import = Aim::CodingImport.last
      assert_redirected_to aim_coding_import_path(import)
      assert import.previewed?
      assert_equal [2, 1, 1], import.report.with_indifferent_access.values_at(:rows, :loadable, :refused)
      assert_equal 0, Aim::CodingRule.count
    end

    test 'the report offers Load anyway for a row the COA objects to' do
      get :show, params: { id: previewed_import.id }

      assert_response :success
      assert_select 'input[name=?]', 'accept_rows[]', 1
      assert_select 'input[type=submit][value=Apply]'
    end

    test 'apply loads the rules with the accepted rows, and undo takes them back' do
      import = previewed_import
      post :apply, params: { id: import.id, accept_rows: ['3'] }

      assert import.reload.applied?
      assert_equal 2, import.loaded_count
      assert_equal Date.current, Aim::CodingRule.first.effective_from
      assert_match(/22304/, Aim::CodingRule.find_by(vendor_name: 'Bad Object').warnings)

      post :undo, params: { id: import.id }
      assert import.reload.undone?
      assert_equal 0, Aim::CodingRule.in_effect.count
    end

    test 'no file is refused' do
      post :create, params: { agency: 'GSA' }
      assert_redirected_to new_aim_coding_import_path
    end
  end
end
