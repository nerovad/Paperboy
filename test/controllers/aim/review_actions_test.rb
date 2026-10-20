# frozen_string_literal: true

require 'test_helper'

module Aim
  # The review page's actions (#182): one main action for the state with Save
  # Changes beside it, the rare and risky in More, whose items press the real
  # buttons kept on the page with their dialogs.
  class ReviewActionsTest < ActionController::TestCase
    tests Aim::InvoicesController

    setup do
      session[:user] = { 'email' => 'aim.staff@example.com', 'employee_id' => 42 }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    def invoice(state, **attributes)
      defaults = { document_type: 'Invoice', vendor_name: 'ACME', invoice_number: 'N-1', budget_unit: '4601',
                   invoice_date: Date.new(2026, 9, 1), invoice_total: 10, submitter: 'Jane Doe' }
      Aim::Invoice.create!(batch_id: "R-#{state}", state: state, actor: 'aim_worker', **defaults.merge(attributes))
    end

    def visible_buttons = css_select('.aim-review-action-strip__main button').map { |button| button.text.squish }

    def more_items = css_select('.aim-review-more .aim-actions-menu__list button').map { |button| button.text.squish }

    test 'Action Needed: Send to Approval is the one main action; the rest are in More, pressing the real buttons' do
      row = invoice('needs_review', review_reason: 'missing_fields')
      get :show, params: { id: row.batch_id, queue: 'needs_review' }

      assert_equal ['Save Changes', 'Send to Approval'], visible_buttons
      assert_equal ['Retry AI', 'Send to a queue…', 'Reject…', 'Delete…'], more_items
      assert_select '.aim-review-more button.aim-actions-menu__danger', count: 2
      %w[aim-act-retry-ai aim-act-send-queue aim-act-reject aim-act-delete].each do |id|
        assert_select "button##{id}[hidden]"
        assert_select '.aim-review-more button[data-aim-press-target-param=?]', id
      end
      assert_select 'button#aim-act-retry-ai[name=invoice_action][value=retry_ai]'
    end

    test 'an unknown vendor learns and sends as its main action' do
      row = invoice('needs_review', review_reason: 'unknown_vendor')
      get :show, params: { id: row.batch_id, queue: 'needs_review' }

      assert_equal ['Save Changes', 'Learn & Send to Approval'], visible_buttons
      assert_equal 'Learn & Retry AI', more_items.first
    end

    test 'Ready for Approval: Approve, with Send Back beside it' do
      row = invoice('ready_for_approval')
      get :show, params: { id: row.batch_id, queue: 'ready_for_approval' }

      assert_equal ['Save Changes', 'Send Back', 'Approve'], visible_buttons
      assert_includes more_items, 'Reject…'
    end

    test 'Failed: the retry its failure calls for is the main action, the other in More' do
      row = invoice('failed', review_reason: 'export_error')
      get :show, params: { id: row.batch_id, queue: 'failed' }
      assert_equal 'Retry Export', visible_buttons.last
      assert_includes more_items, 'Retry AI'

      row.update_columns(review_reason: 'extraction_error')
      get :show, params: { id: row.batch_id, queue: 'failed' }
      assert_equal 'Retry AI', visible_buttons.last
      assert_includes more_items, 'Retry Export'
    end
  end
end
