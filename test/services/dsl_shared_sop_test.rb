# frozen_string_literal: true

require 'test_helper'

class DslSharedSopTest < ActiveSupport::TestCase
  test 'loads an editable shared SOP snippet' do
    sop = DslSharedSop.fetch!(:chart_of_accounts)

    assert_equal 'How to Refresh the Chart of Accounts', sop.fetch(:title)
    assert_equal :source_group, sop.fetch(:reference_group)
  end

  test 'loads the shared Print 2 Mail SOP' do
    sop = DslSharedSop.fetch!(:print_2_mail)

    assert_equal 'How to Refresh Print 2 Mail', sop.fetch(:title)
    assert_equal :source_location, sop.fetch(:reference_path)
  end

  test 'rejects unknown shared SOPs' do
    assert_raises(KeyError) { DslSharedSop.fetch!(:unknown) }
    assert_raises(KeyError) { DslSharedSop.fetch!('../agencies') }
  end
end
