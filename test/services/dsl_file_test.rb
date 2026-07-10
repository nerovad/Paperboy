# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class DslFileTest < ActiveSupport::TestCase
  test "syntax checks source before replacing a DSL file" do
    Dir.mktmpdir do |directory|
      path = Pathname(directory).join("sample.rb")
      path.write("['Sample', {}]\n")
      entry = DslCatalog::Entry.new(key: "Sample", slug: "sample", path: path, config: {})

      assert_raises(SyntaxError) { DslFile.new(entry).write!("[broken") }
      assert_equal "['Sample', {}]\n", path.read

      DslFile.new(entry).write!("['Changed', {}]\n")
      assert_equal "['Changed', {}]\n", path.read
    end
  ensure
    DslCatalog.reload!
  end
end
