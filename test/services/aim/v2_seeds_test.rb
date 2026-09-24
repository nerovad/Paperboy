# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # The v1 JSON files go into the v2 tables once; running the seed again
  # changes nothing already there.
  class V2SeedsTest < ActiveSupport::TestCase
    AIM_ENV = %w[AIM_WINDOWS_QUEUE_BASE_PATH AIM_LINUX_QUEUE_BASE_PATH AIM_PROGRAM_DIR AIM_STORE_DIR].freeze

    setup do
      @tmpdir = Dir.mktmpdir
      @old_env = AIM_ENV.to_h { |key| [key, ENV.fetch(key, nil)] }
      ENV['AIM_WINDOWS_QUEUE_BASE_PATH'] = 'E:\AIM'
      ENV['AIM_LINUX_QUEUE_BASE_PATH'] = @tmpdir
      ENV['AIM_PROGRAM_DIR'] = 'E:\AIM\_WORKERS'
      ENV['AIM_STORE_DIR'] = 'E:\AIM\_BACK_END\_STORE'
      FileUtils.mkdir_p(File.join(@tmpdir, '_WORKERS'))
    end

    teardown do
      @old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
    end

    test 'a bare file name resolves under the program folder' do
      assert_equal File.join(@tmpdir, '_WORKERS', 'vendor_aliases.json'), Aim::V2Seeds.resolve('vendor_aliases.json')
      assert_equal File.join(@tmpdir, 'elsewhere', 'a.json'), Aim::V2Seeds.resolve('E:\AIM\elsewhere\a.json')
    end

    test 'aliases are seeded once' do
      path = File.join(@tmpdir, '_WORKERS', 'vendor_aliases.json')
      File.write(path, { 'AIRGAS USA LLC' => 'Airgas', 'Airgas' => 'Airgas', '' => 'x' }.to_json)
      Aim::VendorAlias.create!(extracted_name: 'airgas usa llc', normalized_name: 'Airgas USA')

      assert_equal [1, 1], Aim::V2Seeds.seed_aliases(path)
      assert_equal [0, 2], Aim::V2Seeds.seed_aliases(path)
      assert_equal 'Airgas USA', Aim::VendorAlias.find_by(extracted_name: 'airgas usa llc').normalized_name,
                   'what is already there is kept'
    end

    test 'rules are seeded once, one line per rule' do
      path = File.join(@tmpdir, '_WORKERS', 'vendor_rules.json')
      File.write(path, { 'Airgas' => ['Invoice number is top right', 'Take the amount due'], 'Empty' => [] }.to_json)

      assert_equal [1, 0], Aim::V2Seeds.seed_rules(path)
      assert_equal [0, 1], Aim::V2Seeds.seed_rules(path)
      assert_equal ['Invoice number is top right', 'Take the amount due'], Aim::VendorRule.for_vendor('airgas').rule_lines
    end

    test 'the rake tasks exist' do
      Rails.application.load_tasks unless Rake::Task.task_defined?('aim:v2:seed_aliases')

      assert Rake::Task.task_defined?('aim:v2:seed_aliases')
      assert Rake::Task.task_defined?('aim:v2:seed_rules')
    end

    test 'the PDFs of rows v1 left open are copied into the store' do
      backend = File.join(@tmpdir, '_BACK_END')
      FileUtils.mkdir_p(File.join(backend, '_VENDOR_REVIEW', '4641.A-[X1Y2]'))
      File.write(File.join(backend, '_VENDOR_REVIEW', '4641.A-[X1Y2]', '4641.A-[X1Y2].pdf'), 'pdf a')
      FileUtils.mkdir_p(File.join(backend, '_REJECTED', 'Jane_4641', '4641.B'))
      File.write(File.join(backend, '_REJECTED', 'Jane_4641', '4641.B', '4641.B.pdf'), 'pdf b')
      Aim::Invoice.create!(batch_id: '4641.A-[X1Y2]', state: 'needs_review', actor: 'test')
      Aim::Invoice.create!(batch_id: '4641.B', state: 'needs_review', actor: 'test')
      Aim::Invoice.create!(batch_id: '4641.C', state: 'needs_review', actor: 'test')
      Aim::Invoice.create!(batch_id: '4641.D', state: 'exported', actor: 'test')

      assert_equal [2, 1], Aim::V2Seeds.adopt_v1_pdfs(backend)

      assert_equal 'pdf a', File.read(File.join(@tmpdir, '_BACK_END', '_STORE', '4641.A-[X1Y2]', '4641.A-[X1Y2].pdf'))
      assert_equal 'pdf b', File.read(File.join(@tmpdir, '_BACK_END', '_STORE', '4641.B', '4641.B.pdf'))
      assert File.exist?(File.join(backend, '_VENDOR_REVIEW', '4641.A-[X1Y2]', '4641.A-[X1Y2].pdf')), 'v1 keeps its copy'
      assert_equal [0, 1], Aim::V2Seeds.adopt_v1_pdfs(backend), 'running it again changes nothing'
    end

    test 'rows v1 left open are closed as deleted, newer rows and finished rows untouched' do
      old = Aim::Invoice.create!(batch_id: '4641.E', state: 'needs_review', actor: 'test')
      done = Aim::Invoice.create!(batch_id: '4641.F', state: 'exported', actor: 'test')
      Aim::Invoice.where(id: [old.id, done.id]).update_all(created_at: 2.days.ago)
      fresh = Aim::Invoice.create!(batch_id: '4641.G', state: 'received', actor: 'test')

      assert_equal 1, Aim::V2Seeds.clear_v1_leftovers(1.day.ago, actor: 'staff@example.com')

      assert_equal(%w[deleted exported received], [old, done, fresh].map { |i| i.reload.state })
      assert_equal 'staff@example.com', old.events.last.actor
    end

    test 'finished rows from before the cutover are purged with their events; open rows stay' do
      gone = Aim::Invoice.create!(batch_id: '4641.H', state: 'exported', actor: 'test')
      open = Aim::Invoice.create!(batch_id: '4641.I', state: 'needs_review', actor: 'test')
      Aim::Invoice.where(id: [gone.id, open.id]).update_all(created_at: 2.days.ago)
      fresh = Aim::Invoice.create!(batch_id: '4641.J', state: 'deleted', actor: 'test')

      assert_equal [1, 1], Aim::V2Seeds.purge_before(1.day.ago)

      assert_nil Aim::Invoice.find_by(id: gone.id)
      assert_empty Aim::InvoiceEvent.where(invoice_id: gone.id)
      assert Aim::Invoice.exists?(open.id)
      assert Aim::Invoice.exists?(fresh.id)
    end
  end
end
