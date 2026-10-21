# frozen_string_literal: true

require 'test_helper'

module Aim
  # The stamp designer (#221): a group's Fiscal design their group's stamp,
  # AIM Admins any group's and the default; a check stamps a real invoice
  # and writes nothing; saving makes a new version and stamps again only
  # what the saver chose.
  class StampLayoutsControllerTest < ActionController::TestCase
    include ActiveJob::TestHelper

    tests Aim::StampLayoutsController

    setup do
      @store = Dir.mktmpdir
      session[:user] = { 'email' => 'fiscal@example.com', 'employee_id' => 42 }
      as_groups
      @gsa = Aim::AgencyGroup.for_agency!('GSA')
      @gsa.roles.create!(employee_id: 42, role: 'fiscal')
      @sheriff = Aim::AgencyGroup.for_agency!('SHF')
    end

    teardown { FileUtils.rm_rf(@store) }

    def as_groups(*names)
      @controller.define_singleton_method(:current_user_group_names) { Set.new(names) }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
    end

    def in_store(&block)
      Aim::InvoiceDirectoryService.instance.stub(:store_dir, @store, &block)
    end

    def invoice(batch_id, agency: 'GSA', state: 'approved')
      row = Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'approver@example.com', agency: agency,
                                 budget_unit: '4601', vendor_name: 'ACME', invoice_number: batch_id)
      FileUtils.mkdir_p(row.store_dir)
      Prawn::Document.generate(row.pdf_path) { |pdf| pdf.text "Invoice #{batch_id}" }
      row
    end

    def areas(*rows_per_area) = rows_per_area.map { |rows| { 'name' => 'Area', 'rows' => rows } }.to_json

    test 'Fiscal see and design their own group only; the default is for AIM Admins' do
      get :index
      assert_response :success
      assert_select 'td', text: @gsa.name
      assert_select 'td', text: @sheriff.name, count: 0
      assert_select 'td', text: /Default/, count: 0

      get :edit, params: { id: @sheriff.id }
      assert_redirected_to aim_stamp_layouts_path
      get :edit, params: { id: 'default' }
      assert_redirected_to aim_stamp_layouts_path

      as_groups('aim_admin')
      get :index
      assert_select 'td', text: /Default/
    end

    test 'the designer opens on the stamp AIM has always written, laid on a group invoice' do
      in_store do
        mine = invoice('4601.MINE')
        invoice('SHF.THEIRS', agency: 'SHF')

        get :edit, params: { id: @gsa.id }

        assert_response :success
        assert_select '[data-controller=stamp-designer][data-stamp-designer-areas-value*=?]', '{approver}_{approved_at}'
        assert_select 'select[data-stamp-designer-target=sample] option', count: 1
        assert_select 'select[data-stamp-designer-target=sample] option[value=?]', mine.id.to_s
      end
    end

    test 'saving makes a new version; still-with-Fiscal invoices are stamped again when asked, others keep theirs' do
      in_store do
        waiting = Aim::FiscalRecord.create!(invoice: invoice('4601.W'), status: 'review', stamped_at: 1.day.ago)
        exported = Aim::FiscalRecord.create!(invoice: invoice('4601.E'), status: 'exported', stamped_at: 1.day.ago)

        assert_enqueued_jobs 1, only: Aim::StampApprovedJob do
          patch :update, params: { id: @gsa.id, areas: areas(['Approved by {approver}']), restamp: 'fiscal', note: 'new wording' }
        end

        layout = Aim::StampLayout.current_for(@gsa)
        assert_equal [['Approved by {approver}'], 'new wording', 'fiscal@example.com'],
                     [layout.area_list.map { |area| area['rows'] }.first, layout.note, layout.created_by]
        assert_nil waiting.reload.stamped_at
        assert_not_nil exported.reload.stamped_at
        assert_match(/1 invoice still with Fiscal will be stamped again/, flash[:notice])

        assert_no_enqueued_jobs only: Aim::StampApprovedJob do
          patch :update, params: { id: @gsa.id, areas: areas(['{approver}']), restamp: 'new' }
        end
        assert_equal 2, Aim::StampLayout.history_for(@gsa).count
      end
    end

    test 'a layout naming an unknown field, or too big for any page, is not saved' do
      patch :update, params: { id: @gsa.id, areas: areas(['{approver} {salary}']), restamp: 'new' }
      assert_match(/unknown fields: salary/, flash[:alert])

      narrow = [{ 'rows' => Array.new(12) { 'Row with a lot of words in it ' * 8 }, 'width' => 40 }].to_json
      patch :update, params: { id: @gsa.id, areas: narrow, restamp: 'new' }
      assert_match(/too big for the page/, flash[:alert])

      assert_equal 0, Aim::StampLayout.count
    end

    test 'a check stamps the invoice with the unsaved layout and writes nothing' do
      in_store do
        row = invoice('4601.C')

        post :preview, params: { id: @gsa.id, invoice_id: row.id, areas: areas(['CHECKED {vendor}']) }

        assert_response :success
        assert_equal 'application/pdf', response.media_type
        assert_includes PDF::Reader.new(StringIO.new(response.body)).pages.first.text, 'CHECKED ACME'
        assert_not File.exist?(Aim::ApprovalStamp.path(row))
        assert_equal 0, Aim::StampLayout.count
      end
    end

    test 'the sample page is the invoice PDF, and only a group invoice' do
      in_store do
        mine = invoice('4601.S')
        theirs = invoice('SHF.S', agency: 'SHF')

        get :sample, params: { id: @gsa.id, invoice_id: mine.id }
        assert_response :success
        assert_equal File.binread(mine.pdf_path), response.body

        get :sample, params: { id: @gsa.id, invoice_id: theirs.id }
        assert_response :not_found
      end
    end
  end
end
