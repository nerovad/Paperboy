# frozen_string_literal: true

require 'test_helper'

module Aim
  # Rejected and Deleted (#169): what nobody has acknowledged yet, however
  # old, counted in the sidebar; Acknowledge one or several and it leaves the
  # list for everyone. Finished, with nothing to acknowledge, has no count.
  class AcknowledgementsTest < ActionController::TestCase
    tests Aim::InvoicesController

    setup do
      session[:user] = { 'email' => 'aim.staff@example.com', 'employee_id' => 42, 'first_name' => 'Aim', 'last_name' => 'Staff' }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    def finished(batch_id, state: 'rejected', days_ago: 1, **attributes)
      defaults = { vendor_name: 'ACME', invoice_number: 'INV-1', budget_unit: '4601', invoice_total: 10 }
      row = Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'aim_worker', **defaults.merge(attributes))
      row.update_column(:finished_at, days_ago.days.ago)
      row
    end

    def listed = @controller.instance_variable_get(:@invoices).map(&:batch_id)

    test 'Rejected and Deleted list what is still to acknowledge, however old, with boxes to tick' do
      finished('NEW', days_ago: 2)
      finished('OLD', days_ago: 400)
      seen = finished('SEEN', days_ago: 2)
      seen.acknowledge!(actor: 'someone@example.com')

      get :index, params: { queue: 'rejected' }
      assert_equal %w[NEW OLD].sort, listed.sort
      assert_select '.aim-archive select[name=days]', count: 0
      assert_select '.aim-archive__window', text: /Waiting to be acknowledged/
      assert_select 'form#aim-acknowledge-form button[disabled]', text: /Acknowledge selected/
      assert_select 'input[type=checkbox][name=?][form=aim-acknowledge-form]', 'ids[]', count: 2
      assert_select 'input[data-action=?]', 'aim-acknowledge#selectAll'

      get :index, params: { queue: 'rejected', vendor: 'ACME' }
      assert_equal %w[NEW OLD SEEN].sort, listed.sort
      assert_select 'span.badge[title^=?]', 'by someone@example.com', text: 'Acknowledged'
    end

    test 'acknowledging one or several takes them off the list for everyone, each with a history line' do
      one = finished('ONE')
      two = finished('TWO', state: 'deleted')
      finished('KEEP')

      patch :acknowledge, params: { queue: 'rejected', ids: %w[ONE TWO] }
      assert_equal 'Acknowledged 2 invoices.', flash[:notice]
      [one, two].each do |row|
        row.reload
        assert_equal 'aim.staff@example.com', row.acknowledged_by
        assert_equal 'acknowledged', row.events.last.action
      end
      assert_equal %w[KEEP], Aim::Invoice.unacknowledged.where(state: %w[rejected deleted]).pluck(:batch_id)

      patch :acknowledge, params: { queue: 'rejected', ids: %w[ONE] }
      assert_equal 'Nothing to acknowledge: those were already acknowledged.', flash[:notice]
      assert_equal 1, one.events.where(action: 'acknowledged').count
    end

    test 'only what Managing serves is acknowledged, and a work-queue invoice never is' do
      finished('MINE', budget_unit: '4601')
      finished('THEIRS', budget_unit: '4602')
      Aim::Invoice.create!(batch_id: 'WORK', state: 'needs_review', actor: 'aim_worker', budget_unit: '4601')
      groups = Object.new
      groups.define_singleton_method(:invoices) { |_| Aim::Invoice.where(budget_unit: '4601') }
      @controller.helpers.define_singleton_method(:aim_agency_groups) { groups }
      @controller.helpers.define_singleton_method(:aim_managing_groups) { [:picked] }

      patch :acknowledge, params: { queue: 'rejected', ids: %w[MINE THEIRS WORK] }
      assert_equal %w[MINE], Aim::Invoice.where.not(acknowledged_at: nil).pluck(:batch_id)
    end

    test 'a restored invoice rejected again comes back to acknowledge, and the counts are what is left' do
      row = finished('BACK')
      finished('ALSO')
      row.acknowledge!(actor: 'aim.staff@example.com')
      assert_equal 1, Aim::Invoice.queue_counts['rejected']

      row.transition_to!('needs_review', actor: 'aim.staff@example.com')
      assert_nil row.acknowledged_at
      row.transition_to!('rejected', actor: 'aim.staff@example.com')
      assert_equal 2, Aim::Invoice.queue_counts['rejected']
    end

    test 'the review page offers Acknowledge and then says who did' do
      row = finished('PAGE')

      get :show, params: { id: 'PAGE', queue: 'rejected' }
      assert_select 'form[action=?] input[name=?][value=PAGE]', acknowledge_aim_invoices_path(queue: 'rejected'), 'ids[]'

      row.acknowledge!(actor: 'someone@example.com')
      get :show, params: { id: 'PAGE', queue: 'rejected' }
      assert_select 'form[action=?]', acknowledge_aim_invoices_path(queue: 'rejected'), count: 0
      assert_match(/Acknowledged by someone@example.com/, response.body)
    end

    test 'the sidebar puts Finished last, after Deleted, with no count' do
      get :index, params: { queue: 'rejected' }

      links = css_select('details[data-key=queues] a.nav-link').map { |link| link.text.squish.sub(/ …\z/, '') }
      assert_equal ['Rejected', 'Deleted', 'Finished', 'By BU'], links.last(4)
      assert_select 'details[data-key=queues] [data-aim-count=exported]', count: 0
      assert_select 'details[data-key=queues] [data-aim-count=deleted]'
    end
  end
end
