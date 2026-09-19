# frozen_string_literal: true

require 'test_helper'

# A template's class_name is the only thing tying it to the form class that
# renders it. The form builder and the duplicator leave it blank and expect one
# derived from the name; db/forms.yml states the real class, which the name
# does not always derive to. Overwriting a stated one filed a template under a
# class no form answers to, and forms:sync then created it again on every run.
module Forms
  class TemplateClassNameTest < ActiveSupport::TestCase
    setup do
      Forms::Template.where(name: ['Safety Reporting', 'Nothing Named This']).destroy_all
    end

    teardown do
      Forms::Template.where(name: ['Safety Reporting', 'Nothing Named This']).destroy_all
    end

    test 'a stated class name survives creation even when the name derives to another' do
      template = create(name: 'Safety Reporting', class_name: 'SafetyReport')

      assert_equal 'SafetyReport', template.reload.class_name
      assert_equal 'SafetyReportingForm', Forms::Template.class_name_for('Safety Reporting')
    end

    test 'a blank class name is still derived from the name' do
      assert_equal 'NothingNamedThisForm', create(name: 'Nothing Named This').class_name
    end

    private

    def create(**attributes)
      Forms::Template.create!({ page_count: 2, submission_type: 'database' }.merge(attributes))
    end
  end
end
