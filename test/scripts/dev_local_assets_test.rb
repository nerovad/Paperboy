# frozen_string_literal: true

require 'minitest/autorun'

# The workstation launcher must leave public/assets empty. A precompiled
# manifest there wins over live compilation, so every JavaScript and
# stylesheet edit made after the server started was served stale -- it
# happened again and again until this test (AGENTS.md, "Working on CSS
# locally").
class DevLocalAssetsTest < Minitest::Test
  LAUNCHER = File.expand_path('../../bin/dev-local', __dir__)

  def commands = File.readlines(LAUNCHER).grep_v(/\A\s*#/).join

  def test_the_launcher_never_precompiles_assets
    refute_match(/assets:precompile/, commands)
  end

  def test_the_launcher_clears_old_precompiled_assets
    assert_match(/assets:clobber/, commands)
  end
end
