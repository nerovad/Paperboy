# frozen_string_literal: true

require 'test_helper'

class DevelopmentScriptCatalogTest < ActiveSupport::TestCase
  test 'run model uses the namespaced table created by the migration' do
    assert_equal 'development_runs', Development::Run.table_name
  end

  test 'catalog contains only allowlisted bin scripts' do
    scripts = Development::ScriptCatalog.scripts

    assert_equal scripts.map { |script| script[:key] }.uniq.length, scripts.length
    assert(scripts.all? { |script| Rails.root.join('bin', script[:bin]).file? })
    refute_includes scripts.map { |script| script[:bin] }, 'gitea-common'
    refute_includes scripts.map { |script| script[:bin] }, 'shell-init'
  end

  test 'command builder creates an argv array rooted in Paperboy' do
    script = Development::ScriptCatalog.find('deploy_stage')
    command = Development::CommandBuilder.new(script, ['v1.2.3']).to_a

    assert_equal Rails.root.join('bin', 'deploy-stage').to_s, command.first
    assert_equal ['v1.2.3'], command.drop(1)
  end

  test 'catalog validates required values before queueing a command' do
    script = Development::ScriptCatalog.find('deploy_production')

    error = assert_raises(ArgumentError) { script[:arguments].call({ tag: '' }) }

    assert_equal 'Release tag is required.', error.message
  end
end
