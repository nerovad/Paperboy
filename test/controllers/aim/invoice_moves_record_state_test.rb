# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # Every move a person makes on the queue screens is recorded on the
  # invoice's row, in their name, and a claim is kept there too. The files still
  # move -- the workers find their work by folder -- but the row now says where
  # the invoice went and who sent it. Plan step 5.7b.
  # rubocop:disable Metrics/ClassLength
  class InvoiceMovesRecordStateTest < ActionController::TestCase
    tests Aim::InvoicesController

    QUEUES = {
      'AIM_ACTION_NEEDED_DIR' => '_ACTION_NEEDED',
      'AIM_SQL_QUEUE_DIR' => '_SQL_QUEUE',
      'AIM_USER_APPROVAL_DIR' => '_USER_APPROVAL',
      'AIM_REJECTED_DIR' => '_REJECTED',
      'AIM_REPROCESS_QUEUE_DIR' => '_REPROCESS_QUEUE',
      'AIM_DELETED_DIR' => '_DELETED',
      'AIM_READY_TO_DELETE_DIR' => '_READY_TO_DELETE'
    }.freeze
    AIM_ENV = (%w[AIM_WINDOWS_QUEUE_BASE_PATH AIM_LINUX_QUEUE_BASE_PATH] + QUEUES.keys).freeze
    REVIEWER = 'aim.staff@example.com'

    setup do
      @tmpdir = Dir.mktmpdir
      @old_env = AIM_ENV.to_h { |key| [key, ENV.fetch(key, nil)] }
      ENV['AIM_WINDOWS_QUEUE_BASE_PATH'] = 'E:\AIM'
      ENV['AIM_LINUX_QUEUE_BASE_PATH'] = @tmpdir
      QUEUES.each do |variable, folder|
        ENV[variable] = "E:\\AIM\\_BACK_END\\#{folder}"
        FileUtils.mkdir_p(File.join(@tmpdir, '_BACK_END', folder))
      end

      session[:user] = { 'email' => REVIEWER, 'employee_id' => 42 }
      @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    end

    teardown do
      @old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
    end

    def action_needed_invoice(batch_id, document_type: 'Invoice', row: true)
      folder = File.join(@tmpdir, '_BACK_END', '_ACTION_NEEDED', batch_id)
      FileUtils.mkdir_p(folder)
      File.write(File.join(folder, "#{batch_id}.pdf"), 'pdf')
      File.write(File.join(folder, "#{batch_id}_READY_FOR_SQL.json"),
                 JSON.pretty_generate('InvoiceNumber' => 'INV-1', 'BU' => '4601', 'Submitter' => 'Jane Doe'))
      if row
        Aim::Invoice.create!(batch_id: batch_id, state: 'action_needed', document_type: document_type,
                             actor: '01_ai_extraction_worker')
      end
      folder
    end

    def last_event(batch_id)
      Aim::Invoice.find_by!(batch_id: batch_id).events.last
    end

    test 'sending an invoice to the SQL queue records the move in the reviewer\'s name' do
      action_needed_invoice('4601.A')

      patch :update, params: { id: '4601.A', queue: 'action_needed', commit: 'Send to SQL Queue' }

      assert_equal 'sql_queue', Aim::Invoice.find_by!(batch_id: '4601.A').state
      event = last_event('4601.A')
      assert_equal ['transition', 'action_needed', 'sql_queue', REVIEWER],
                   [event.action, event.from_state, event.to_state, event.actor]
    end

    test 'sending an invoice to a user records it' do
      action_needed_invoice('4601.B')

      patch :update, params: { id: '4601.B', queue: 'action_needed', commit: 'Send to Approval' }

      assert_equal 'user_approval', Aim::Invoice.find_by!(batch_id: '4601.B').state
      assert Dir.exist?(File.join(@tmpdir, '_BACK_END', '_USER_APPROVAL', '4601.B'))
    end

    test 'an invoice still typed Unknown is not sent to a user, and nothing moves' do
      folder = action_needed_invoice('4601.C', document_type: 'Unknown')

      patch :update, params: { id: '4601.C', queue: 'action_needed', commit: 'Send to Approval' }

      assert_match(/still typed Unknown/, flash[:alert])
      assert Dir.exist?(folder), 'the files stay where they are'
      assert_equal 'action_needed', Aim::Invoice.find_by!(batch_id: '4601.C').state
    end

    test 'setting the type in the metadata grid lets it through' do
      action_needed_invoice('4601.D', document_type: 'Unknown')

      patch :update, params: { id: '4601.D', queue: 'action_needed', commit: 'Save & Send to Approval',
                               metadata: { 'DocumentType' => 'credit' } }

      invoice = Aim::Invoice.find_by!(batch_id: '4601.D')
      assert_equal 'Credit', invoice.document_type
      assert_equal 'user_approval', invoice.state
    end

    test 'rejecting an invoice records it as rejected' do
      action_needed_invoice('4601.E')

      patch :update, params: { id: '4601.E', queue: 'action_needed', commit: 'Reject',
                               metadata: { 'Submitter' => 'Jane Doe', 'BU' => '4601' } }

      assert_equal 'rejected', Aim::Invoice.find_by!(batch_id: '4601.E').state
      assert_equal REVIEWER, last_event('4601.E').actor
    end

    test 'an AI retry records the original as deleted and says where it went' do
      action_needed_invoice('4601.F')

      post :retry, params: { id: '4601.F', queue: 'action_needed' }

      assert_equal 'deleted', Aim::Invoice.find_by!(batch_id: '4601.F').state
      assert_match(/sent back for AI retry as 4601\.F_RETRY_/, last_event('4601.F').note)
    end

    test 'a move of an invoice the database never saw adopts it' do
      action_needed_invoice('4601.G', row: false)

      patch :update, params: { id: '4601.G', queue: 'action_needed', commit: 'Send to SQL Queue' }

      assert_equal 'sql_queue', Aim::Invoice.find_by!(batch_id: '4601.G').state
    end

    test 'a database that will not record the move does not stop it' do
      folder = action_needed_invoice('4601.H')

      Aim::Invoice.stub(:record_move!, ->(*) { raise ActiveRecord::ConnectionNotEstablished }) do
        patch :update, params: { id: '4601.H', queue: 'action_needed', commit: 'Send to SQL Queue' }
      end

      assert_redirected_to aim_invoices_path(queue: 'action_needed')
      assert_not Dir.exist?(folder)
      assert Dir.exist?(File.join(@tmpdir, '_BACK_END', '_SQL_QUEUE', '4601.H'))
    end

    test 'opening an invoice claims it on the row as well as in the folder' do
      action_needed_invoice('4601.I')

      get :show, params: { id: '4601.I', queue: 'action_needed' }

      assert_equal REVIEWER, Aim::Invoice.find_by!(batch_id: '4601.I').claimed_by
    end

    test 'opening an invoice records the claimant by name on the row' do
      session[:user] = session[:user].merge('first_name' => 'Aim', 'last_name' => 'Staff')
      action_needed_invoice('4601.K')

      get :show, params: { id: '4601.K', queue: 'action_needed' }

      assert_equal 'Aim Staff', Aim::Invoice.find_by!(batch_id: '4601.K').claimed_by_name
    end

    test 'a claim on the row makes the invoice read only for anyone else, naming them' do
      action_needed_invoice('4601.L')
      Aim::Invoice.find_by!(batch_id: '4601.L').claim!('other.staff@example.com', name: 'Dana Reyes')

      get :show, params: { id: '4601.L', queue: 'action_needed' }

      assert_includes response.body, 'Dana Reyes claimed this invoice'
      assert_select 'input[type=submit][value=?]', 'Save Changes', false
    end

    test 'the queue list names the claimant from the row' do
      action_needed_invoice('4601.M')
      Aim::Invoice.find_by!(batch_id: '4601.M').claim!('other.staff@example.com', name: 'Dana Reyes')

      get :index, params: { queue: 'action_needed' }

      assert_includes response.body, 'Claimed by Dana Reyes'
      assert_select 'a', text: 'View Only'
    end

    test 'the row beats a claim file left behind' do
      folder = action_needed_invoice('4601.N')
      File.write(File.join(folder, '.claim.json'), { user: 'other.staff@example.com', name: 'Dana Reyes' }.to_json)
      Aim::Invoice.find_by!(batch_id: '4601.N').claim!(REVIEWER, name: 'Aim Staff')

      get :show, params: { id: '4601.N', queue: 'action_needed' }

      assert_select 'input[type=submit][value=?]', 'Save Changes'
      assert_not_includes response.body, 'Dana Reyes claimed this invoice'
    end

    test 'delete sends the folder to the delete queue and records who did it' do
      folder = action_needed_invoice('4601.O')

      patch :update, params: { id: '4601.O', queue: 'action_needed', commit: 'Delete' }

      assert_not Dir.exist?(folder)
      assert Dir.exist?(File.join(@tmpdir, '_BACK_END', '_READY_TO_DELETE', '4601.O'))
      invoice = Aim::Invoice.find_by!(batch_id: '4601.O')
      assert_equal 'ready_to_delete', invoice.state
      assert_equal REVIEWER, invoice.events.last.actor
    end

    test 'action needed offers Send to SQL Queue, as its shortcut did' do
      action_needed_invoice('4601.R')

      get :show, params: { id: '4601.R', queue: 'action_needed' }

      assert_select 'input[type=submit][value=?][data-turbo-confirm]', 'Send to SQL Queue'
    end

    test 'the review page offers Delete, and asks first' do
      action_needed_invoice('4601.P')

      get :show, params: { id: '4601.P', queue: 'action_needed' }

      assert_select 'input[type=submit][value=?][data-turbo-confirm][data-confirm-label=?]', 'Delete', 'Delete'
    end

    test 'delete is refused where the pipeline does not allow it' do
      folder = File.join(@tmpdir, '_BACK_END', '_SQL_QUEUE', '4601.Q')
      FileUtils.mkdir_p(folder)
      File.write(File.join(folder, '4601.Q.pdf'), 'pdf')

      @controller.stub(:set_queue, -> { @controller.instance_variable_set(:@queue, 'sql_queue') }) do
        patch :update, params: { id: '4601.Q', queue: 'sql_queue', commit: 'Delete' }
      end

      assert Dir.exist?(folder), 'an invoice in the SQL queue is on its way to Laserfiche, not deletable'
    end

    test 'unclaiming releases the row too' do
      action_needed_invoice('4601.J')
      get :show, params: { id: '4601.J', queue: 'action_needed' }

      patch :update, params: { id: '4601.J', queue: 'action_needed', commit: 'Unclaim' }

      assert_nil Aim::Invoice.find_by!(batch_id: '4601.J').claimed_by
    end
  end
  # rubocop:enable Metrics/ClassLength
end
