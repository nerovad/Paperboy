# frozen_string_literal: true

require 'test_helper'
require_relative 'configuration_scanner'

# Guards the AIM configuration protocol.
#
# Every filesystem path, share name, server name, database name, user name,
# password, ODBC property and model name comes from an environment variable
# defined in LockBox. None of them is ever written as a literal.
#
# This is not style. Everyone working on Paperboy has a different local setup,
# so a literal path is a path that works on exactly one machine -- and a wrong
# guess is how an invoice ends up in a folder nobody is watching. Moving AIM to
# a different database server must be a LockBox edit and nothing else.
#
# Phase 0 of docs/aim/aim_plan.md removed every such literal. This test is what
# stops them coming back: a hardcoded path is a red build here rather than
# something discovered months later on the share.
module Aim
  class ConfigurationConventionsTest < ActiveSupport::TestCase
    include ConfigurationScanner

    RUBY_GLOBS = [
      'app/controllers/aim/**/*.rb', 'app/controllers/concerns/aim/**/*.rb',
      'app/helpers/aim/**/*.rb', 'app/models/aim/**/*.rb',
      'app/services/aim/**/*.rb', 'app/views/aim/**/*.erb'
    ].freeze

    # .bat launchers are deliberately out of scope: their only job is to start a
    # worker on the server, so they are the thing being launched *by* the
    # environment rather than code that reads configuration. See the plan's
    # Guardrails, exception 1.
    PYTHON_GLOB = 'script/python/aim/*.py'

    # A drive letter, but not the ":\n" inside an ordinary string.
    WINDOWS_DRIVE = /(?<![A-Za-z0-9_])[A-Za-z]:\\/
    UNC_SHARE = /\\\\[A-Za-z0-9-]+\\/
    MOUNT_POINT = %r{/mnt/}
    # 'Encrypt=no' inside a connection string, not `encrypt = env(...)`.
    ODBC_LITERAL = /ODBC\s+Driver|Encrypt=[A-Za-z]/i
    MODEL_LITERAL = /\bmodel\s*=\s*['"]/
    SERVER_LITERAL = /gsa-sql\d|GSASQL\d|GSAScanCenter/i
    CREDENTIAL_LITERAL = /(password|pwd|uid)\s*=\s*['"][^'"{]/i

    test 'no AIM source hardcodes a Windows path, UNC share or mount point' do
      [WINDOWS_DRIVE, UNC_SHARE, MOUNT_POINT].each do |pattern|
        offences = scan(RUBY_GLOBS, pattern) + scan(PYTHON_GLOB, pattern)
        assert_empty offences,
                     'AIM code must not contain a machine-specific path. Read it from a ' \
                     "LockBox variable instead:\n  #{offences.join("\n  ")}"
      end
    end

    test 'no AIM source hardcodes a queue folder name' do
      offences = files([*RUBY_GLOBS, PYTHON_GLOB]).flat_map do |path|
        prose = docstring_lines(path)
        File.readlines(path, chomp: true).filter_map.with_index(1) do |line, number|
          next if comment?(line, path) || prose.include?(number)

          found = quoted_strings(line).select { |s| QUEUE_FOLDERS.any? { |folder| path_like?(s, folder) } }
          next if found.empty?

          "#{Pathname.new(path).relative_path_from(Rails.root)}:#{number}: #{found.join(', ')}"
        end
      end

      assert_empty offences,
                   'A queue folder was named as a literal. Every queue has a variable ' \
                   "(see Aim::InvoiceDirectoryService::PATH_ENV):\n  #{offences.join("\n  ")}"
    end

    test 'no AIM source hardcodes an ODBC driver or encryption setting' do
      offences = scan(RUBY_GLOBS, ODBC_LITERAL) + scan(PYTHON_GLOB, ODBC_LITERAL)

      assert_empty offences,
                   'The ODBC driver and encryption are properties of the server, not of ' \
                   'AIM, and differ on SQL Server 2022. Use AIM_ODBC_DRIVER and ' \
                   "AIM_ODBC_ENCRYPT:\n  #{offences.join("\n  ")}"
    end

    test 'no AIM source hardcodes a model name' do
      offences = scan(PYTHON_GLOB, MODEL_LITERAL)

      assert_empty offences,
                   'Model names change with the hardware and belong in LockBox. Use ' \
                   "AIM_VISION_MODEL, AIM_TEXT_MODEL or AIM_BENCHMARK_MODEL_A/_B:\n  " \
                   "#{offences.join("\n  ")}"
    end

    test 'no AIM source hardcodes a server name or credential' do
      [SERVER_LITERAL, CREDENTIAL_LITERAL].each do |pattern|
        offences = scan(RUBY_GLOBS, pattern) + scan(PYTHON_GLOB, pattern)
        assert_empty offences,
                     'Server names and credentials come from LockBox, and are never ' \
                     "written, printed or logged:\n  #{offences.join("\n  ")}"
      end
    end

    test 'the Python env reader offers no fallback' do
      source = File.read(Rails.root.join('script/python/aim/pipeline_common.py'))

      assert_match(/^def env\(name\):/, source,
                   'env() must take a name and nothing else. A fallback parameter is a ' \
                   'hardcoded location living in the code, and it is what made every ' \
                   'violation this test guards against possible in the first place.')
      refute_match(/\benv\(\s*['"][A-Z0-9_]+['"]\s*,/, source,
                   'env() was called with a fallback. A missing variable must stop the ' \
                   'worker, not invent a path.')
    end

    test 'the env file search does not walk parents or the working directory' do
      source = File.read(Rails.root.join('script/python/aim/pipeline_common.py'))
      seed = source[/def env_file_candidates.*?\n(?=\ndef |\nENV_FILE)/m].to_s

      refute_match(/os\.getcwd/, seed,
                   'The working directory is not a safe place to look for configuration: ' \
                   'a worker would pick up whichever .env it happened to be started next to.')
      refute_match(/'\.\.'|"\.\."/, seed,
                   'Walking parent directories for a .env lets a stranger\'s file win. ' \
                   'The seed is AIM_ENV_FILE, then the script directory. Nothing else.')
    end

    test 'AIM tests never reference real infrastructure' do
      test_files = files(['test/**/aim/**/*.rb', 'test/**/aim*_test.rb', 'test/python/aim/*.py'])
      real = %r{/mnt/a\b|gsa-scan02|gsa-sql\d|GSASQL\d}i

      offences = test_files.flat_map do |path|
        next [] if path == __FILE__ # this guard names them in order to forbid them

        prose = docstring_lines(path)
        File.readlines(path, chomp: true).filter_map.with_index(1) do |line, number|
          next if comment?(line, path) || prose.include?(number)

          "#{Pathname.new(path).relative_path_from(Rails.root)}:#{number}: #{line.strip}" if line.match?(real)
        end
      end

      assert_empty offences,
                   'AIM tests inject their own configuration and point at a temp ' \
                   'directory. Touching the real share or a real server makes the suite ' \
                   'depend on a machine, and breaks it for anyone who has not pulled ' \
                   "LockBox:\n  #{offences.join("\n  ")}"
    end
  end
end
