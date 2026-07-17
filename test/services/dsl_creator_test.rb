# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require Rails.root.join('script/ruby/data_runner/constants/workflow')

class DslCreatorTest < ActiveSupport::TestCase
  test 'creates a loadable DSL with selected DataRunner commands' do
    Dir.mktmpdir do |directory|
      slug = DslCreator.new(name: 'sample_data', commands: %w[download inject], directory: directory).create!
      path = Pathname(directory).join('sample_data.rb')
      source = path.read
      key, config = TOPLEVEL_BINDING.eval(path.read, path.to_s)

      assert_equal 'sample_data', slug
      assert_equal 'Sample Data', key
      assert_nil config[:commands]
      assert_includes source, 'manual_steps: Workflow::MANUAL_STEPS'
      assert_includes source, 'steps: Workflow::SCHEDULED_STEPS'
      assert_match(/\{\n    steps: \{/, source)
      assert_equal Workflow::MANUAL_STEPS, config.dig(:steps, :manual_steps)
      assert_equal Workflow::SCHEDULED_STEPS, config.dig(:steps, :scheduled, :steps)
    end
  end

  test 'creates a qualified DSL target with database connection values' do
    Dir.mktmpdir do |directory|
      slug = DslCreator.new(name: 'GSASQL16.GSA Scan.dbo.document_automation',
                            commands: ['inject'], directory: directory).create!
      path = Pathname(directory).join('document_automation.rb')
      _key, config = TOPLEVEL_BINDING.eval(path.read, path.to_s)
      connection = config.fetch(:database_connections).first

      assert_equal 'document_automation', slug
      assert_equal 'GSASQL16', connection[:host]
      assert_equal 'GSA Scan', connection[:database]
      assert_equal 'dbo', connection[:schema]
      assert_equal 'document_automation', connection[:table]
    end
  end

  test 'rejects unsafe names, missing commands, and existing DSLs' do
    Dir.mktmpdir do |directory|
      assert_raises(DslCreator::InvalidDsl) { DslCreator.new(name: '../bad', commands: ['inject'], directory: directory).create! }
      assert_raises(DslCreator::InvalidDsl) { DslCreator.new(name: 'server.database.dsl', commands: ['inject'], directory: directory).create! }
      assert_raises(DslCreator::InvalidDsl) { DslCreator.new(name: 'valid', commands: [], directory: directory).create! }

      creator = DslCreator.new(name: 'valid', commands: ['inject'], directory: directory)
      creator.create!
      assert_raises(DslCreator::InvalidDsl) { creator.create! }
    end
  end
end
