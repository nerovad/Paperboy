# frozen_string_literal: true

require 'test_helper'

module Pfa
  module Work
    class ItemTest < ActiveSupport::TestCase
      test 'requires a stable source identity' do
        error = assert_raises(ArgumentError) do
          Pfa::Work::Item.new(application: :aim, source_type: 'Aim::Invoice', source_id: '1', title: 'Invoice')
        end

        assert_equal 'key is required', error.message
      end

      test 'normalizes identifiers and exposes assignment state' do
        item = Pfa::Work::Item.new(
          key: 'aim:invoice:1', application: 'aim', source_type: 'Aim::Invoice',
          source_id: 1, title: 'Invoice', assignee_employee_id: 42,
          status_category: :in_review
        )

        assert_equal :aim, item.application
        assert_equal '1', item.source_id
        assert item.assigned_to?('42')
        assert_not item.terminal?
      end
    end
  end
end
