# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  # The v1 JSON files go into the v2 tables once; running the seed again
  # changes nothing already there.
  class V2SeedsTest < ActiveSupport::TestCase
    AIM_ENV = %w[AIM_WINDOWS_QUEUE_BASE_PATH AIM_LINUX_QUEUE_BASE_PATH AIM_PROGRAM_DIR].freeze

    setup do
      @tmpdir = Dir.mktmpdir
      @old_env = AIM_ENV.to_h { |key| [key, ENV.fetch(key, nil)] }
      ENV['AIM_WINDOWS_QUEUE_BASE_PATH'] = 'E:\AIM'
      ENV['AIM_LINUX_QUEUE_BASE_PATH'] = @tmpdir
      ENV['AIM_PROGRAM_DIR'] = 'E:\AIM\_WORKERS'
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
  end
end
