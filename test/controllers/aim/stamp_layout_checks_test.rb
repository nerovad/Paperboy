# frozen_string_literal: true

require 'test_helper'

module Aim
  # The stamp designer's Check (#221): the chosen invoice, or an uploaded PDF,
  # stamped with the unsaved layout; nothing is written or kept.
  class StampLayoutChecksTest < ActionController::TestCase
    tests Aim::StampLayoutsController

    setup do
      @store = Dir.mktmpdir
      session[:user] = { 'email' => 'fiscal@example.com', 'employee_id' => 42 }
      @controller.define_singleton_method(:current_user_group_names) { Set.new }
      @controller.helpers.define_singleton_method(:can_access_app?) { |*| true }
      @gsa = Aim::AgencyGroup.for_agency!('GSA')
      @gsa.roles.create!(employee_id: 42, role: 'fiscal')
    end

    teardown { FileUtils.rm_rf(@store) }

    def in_store(&block)
      Aim::InvoiceDirectoryService.instance.stub(:store_dir, @store, &block)
    end

    def invoice(batch_id)
      row = Aim::Invoice.create!(batch_id: batch_id, state: 'approved', actor: 'approver@example.com', agency: 'GSA',
                                 budget_unit: '4601', vendor_name: 'ACME', invoice_number: batch_id)
      FileUtils.mkdir_p(row.store_dir)
      Prawn::Document.generate(row.pdf_path) { |pdf| pdf.text "Invoice #{batch_id}" }
      row
    end

    def areas(*rows_per_area) = rows_per_area.map { |rows| { 'name' => 'Area', 'rows' => rows } }.to_json

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

    test 'a check can be on an uploaded PDF, with sample values; it is kept nowhere' do
      upload = File.join(@store, 'mine.pdf')
      Prawn::Document.generate(upload) { |pdf| pdf.text 'My own file' }

      post :preview, params: { id: @gsa.id, areas: areas(['UPLOADED {vendor}']), page_shrink: '80', page_position: 'top',
                               file: Rack::Test::UploadedFile.new(upload, 'application/pdf') }

      assert_response :success
      text = PDF::Reader.new(StringIO.new(response.body)).pages.first.text
      assert_includes text, 'UPLOADED Iron Mountain'
      assert_includes text, 'My own file'

      not_pdf = File.join(@store, 'note.pdf')
      File.write(not_pdf, 'hello')
      post :preview, params: { id: @gsa.id, areas: areas(['X']), file: Rack::Test::UploadedFile.new(not_pdf, 'application/pdf') }
      assert_response :not_found
    end

    test "the live view and Check fill alike: an invoice's own values, samples where it has none" do
      in_store do
        row = invoice('4601.F')

        get :values, params: { id: @gsa.id, invoice_id: row.id }
        values = response.parsed_body
        assert_equal ['ACME', '004512'], [values.dig('vendor', 'value'), values.dig('check_number', 'value')],
                     'its own vendor; no check yet, so the sample check number'

        post :preview, params: { id: @gsa.id, invoice_id: row.id, areas: areas(['{vendor} check {check_number}']) }
        assert_includes PDF::Reader.new(StringIO.new(response.body)).pages.first.text, 'ACME check 004512'

        post :preview, params: { id: @gsa.id, invoice_id: row.id, fill: 'worst', areas: areas(['{approver}']) }
        assert_includes PDF::Reader.new(StringIO.new(response.body)).pages.first.text, 'Montgomery-Fitzgerald'
      end
    end
  end
end
