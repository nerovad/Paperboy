# frozen_string_literal: true

require 'test_helper'

module Forms
  class Duplicator
    class ComponentsTest < ActiveSupport::TestCase
      test 'the definition is always copied' do
        assert_equal %w[definition], Components.normalize([])
        assert_equal %w[definition views], Components.normalize(%w[views])
      end

      test 'unknown keys are dropped and order follows the dialog' do
        assert_equal %w[definition table views], Components.normalize(%w[views bogus table])
      end

      test 'every requirement names a real component' do
        Components::ALL.each do |component|
          component.requires.each { |key| assert Components.find(key), "#{component.key} requires unknown #{key}" }
        end
      end

      test 'a set missing a requirement is refused' do
        missing = Components.missing_requirements(%w[definition controller model table workflow])

        assert_equal 2, missing.size
        assert(missing.any? { |message| message.include?('Views') })
        assert(missing.any? { |message| message.include?('PDF generator') })
      end

      test 'a requirement the form has nothing for does not count' do
        assert_empty Components.missing_requirements(%w[definition controller model table views workflow], %w[pdf])
      end

      test 'the full set stands on its own' do
        assert_empty Components.missing_requirements(Components::KEYS)
      end
    end
  end
end
