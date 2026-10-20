# frozen_string_literal: true

require 'test_helper'

# The document types are declared twice: the workers classify by
# DOCUMENT_TYPES in script/python/aim/pipeline_common.py, and Rails validates
# against Aim::Invoice::DOCUMENT_TYPES. Two languages, one decision -- so the
# only thing that keeps them honest is this test.
#
# If they drift, an invoice the workers typed legitimately becomes one Rails
# refuses to save, or Rails offers a reviewer a type the pipeline has never
# heard of. Plan step 5.4, and Decisions -> Document types.
module Aim
  class DocumentTypesTest < ActiveSupport::TestCase
    PIPELINE_COMMON = Rails.root.join('script/python/aim/pipeline_common.py')

    test 'Rails and the workers know the same document types' do
      source = PIPELINE_COMMON.read
      declaration = source[/^DOCUMENT_TYPES\s*=\s*\(([^)]*)\)/, 1]

      assert declaration, "DOCUMENT_TYPES is not declared in #{PIPELINE_COMMON}"
      assert_equal declaration.scan(/"([^"]+)"/).flatten, Aim::Invoice::DOCUMENT_TYPES
    end

    test 'both call the unsettled type the same thing' do
      unknown = PIPELINE_COMMON.read[/^UNKNOWN_DOCUMENT_TYPE\s*=\s*"([^"]+)"/, 1]

      assert_equal unknown, Aim::Invoice::UNSETTLED_DOCUMENT_TYPE
    end

    # The worker dates an invoice's finish on the same states Rails does (#169).
    test 'Rails and the workers finish on the same states' do
      declaration = Rails.root.join('script/python/aim/v2/store.py').read[/^FINISHED_STATES\s*=\s*\(([^)]*)\)/, 1]

      assert declaration, 'FINISHED_STATES is not declared in script/python/aim/v2/store.py'
      assert_equal Aim::Invoice::TERMINAL_STATES.sort, declaration.scan(/"([^"]+)"/).flatten.sort
    end
  end
end
