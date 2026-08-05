# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module Aim
  class VendorAliasServiceTest < ActiveSupport::TestCase
    setup do
      @tmpdir = Dir.mktmpdir
      @alias_file = File.join(@tmpdir, 'vendor_aliases.json')
      @old_alias_file = ENV.fetch('AIM_ALIAS_DB_FILE', nil)
      @old_linux_base = ENV.fetch('AIM_LINUX_QUEUE_BASE_PATH', nil)
      @old_windows_base = ENV.fetch('AIM_WINDOWS_QUEUE_BASE_PATH', nil)
      ENV['AIM_ALIAS_DB_FILE'] = @alias_file
    end

    teardown do
      @old_alias_file.nil? ? ENV.delete('AIM_ALIAS_DB_FILE') : ENV['AIM_ALIAS_DB_FILE'] = @old_alias_file
      @old_linux_base.nil? ? ENV.delete('AIM_LINUX_QUEUE_BASE_PATH') : ENV['AIM_LINUX_QUEUE_BASE_PATH'] = @old_linux_base
      @old_windows_base.nil? ? ENV.delete('AIM_WINDOWS_QUEUE_BASE_PATH') : ENV['AIM_WINDOWS_QUEUE_BASE_PATH'] = @old_windows_base
      FileUtils.remove_entry(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
    end

    test 'loads unique official names from the alias JSON file' do
      File.write(
        @alias_file,
        JSON.pretty_generate(
          'AIRGAS USA LLC' => 'AIRGAS USA, LLC',
          'AIRGAS USA, LLC' => 'AIRGAS USA, LLC',
          'TEAM PLAY' => 'Team Play Events'
        )
      )

      assert_equal ['AIRGAS USA, LLC', 'Team Play Events'], VendorAliasService.official_names
    end

    test 'writes learned aliases to the alias JSON file' do
      File.write(@alias_file, JSON.pretty_generate('AIRGAS USA, LLC' => 'AIRGAS USA, LLC'))

      VendorAliasService.learn!(
        extracted_name: 'AIR GAS',
        normalized_name: 'AIRGAS USA, LLC',
        learned_by: 'aim.staff@example.com'
      )

      aliases = JSON.parse(File.read(@alias_file))
      assert_equal 'AIRGAS USA, LLC', aliases['AIR GAS']
      assert_equal 'AIRGAS USA, LLC', aliases['AIRGAS USA, LLC']
    end

    test 'defaults to the mounted AIM program alias file' do
      ENV.delete('AIM_ALIAS_DB_FILE')
      ENV['AIM_LINUX_QUEUE_BASE_PATH'] = @tmpdir

      assert_equal(
        Pathname.new(File.join(@tmpdir, '_PROGRAM', 'vendor_aliases.json')),
        VendorAliasService.alias_file_path
      )
    end

    test 'translates configured Windows alias path to the mounted Linux path' do
      ENV['AIM_LINUX_QUEUE_BASE_PATH'] = @tmpdir
      ENV['AIM_WINDOWS_QUEUE_BASE_PATH'] = 'E:\AIM'
      ENV['AIM_ALIAS_DB_FILE'] = 'E:\AIM\_PROGRAM\vendor_aliases.json'

      assert_equal(
        Pathname.new(File.join(@tmpdir, '_PROGRAM', 'vendor_aliases.json')),
        VendorAliasService.alias_file_path
      )
    end

    test 'resolves configured relative alias path inside the mounted program folder' do
      ENV['AIM_LINUX_QUEUE_BASE_PATH'] = @tmpdir
      ENV['AIM_ALIAS_DB_FILE'] = 'vendor_aliases.json'

      assert_equal(
        Pathname.new(File.join(@tmpdir, '_PROGRAM', 'vendor_aliases.json')),
        VendorAliasService.alias_file_path
      )
    end
  end
end
