# frozen_string_literal: true

require 'test_helper'

module Billing
  class DocumentAutomationTest < ActiveSupport::TestCase
    test 'does not include Document Automation in manual Billing refreshes' do
      assert_not_predicate DslCatalog.find!('document_automation'), :enabled?
    end
  end
end
