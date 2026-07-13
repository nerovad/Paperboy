# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class DslDestroyerTest < ActiveSupport::TestCase
  test 'deletes the DSL and exact workflow outputs but preserves scripts' do
    Dir.mktmpdir do |directory|
      root = Pathname(directory)
      data_runner_dsl_path = write(root.join('dsl/sample.rb'), "['Sample', {}]\n")
      output = write(root.join('02_Normalized/sample.csv'), "id\n1\n")
      similarly_named = write(root.join('02_Normalized/sample_extra.csv'), "id\n2\n")
      script = write(root.join('scripts/sample.rb'), "puts 'keep me'\n")
      entry = DslCatalog::Entry.new(key: 'Sample', slug: 'sample', path: data_runner_dsl_path, config: {})

      deleted = DslDestroyer.new(entry, root: root).destroy!

      assert_equal [output], deleted
      assert_not data_runner_dsl_path.exist?
      assert_not output.exist?
      assert similarly_named.exist?
      assert script.exist?
    end
  end

  private

  def write(path, content)
    path.dirname.mkpath
    path.write(content)
    path
  end
end
