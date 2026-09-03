# frozen_string_literal: true

require 'test_helper'

class InboxDslCreatorTest < ActiveSupport::TestCase
  test 'runs inbox discovery and reports newly created DSLs' do
    status = Struct.new(:success?).new(true)
    entries = [[Struct.new(:slug).new('existing')],
               [Struct.new(:slug).new('existing'), Struct.new(:slug).new('new_file')]]

    DslCatalog.stub(:entries, -> { entries.shift }) do
      DslCatalog.stub(:reload!, nil) do
        Open3.stub(:capture2e, ["[OK] new_file.csv\n", status]) do
          result = InboxDslCreator.new.create!

          assert_equal ['new_file'], result.created_slugs
        end
      end
    end
  end
end
