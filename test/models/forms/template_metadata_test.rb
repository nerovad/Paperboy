# frozen_string_literal: true

require 'test_helper'

# The metadata the sidebar's Advanced Search narrows on. Built in memory —
# these are attribute rules, and saving a template generates controllers and
# views as a side effect.
module Forms
  class TemplateMetadataTest < ActiveSupport::TestCase
    def template(**attributes)
      Forms::Template.new(**attributes)
    end

    test 'a form type has to come from the fixed vocabulary' do
      subject = template(name: 'Thing', form_type: 'Whatever')

      assert_not subject.valid?
      assert_includes subject.errors[:form_type], 'is not included in the list'
    end

    test 'leaving the form type unset is allowed' do
      subject = template(name: 'Thing', form_type: '')
      subject.valid?

      assert_empty subject.errors[:form_type]
    end

    test 'org codes come back outermost first, and only the levels that are set' do
      subject = template(agency_id: 'AA1', department_id: 'P1', unit_id: '  ')

      assert_equal({ agency: 'AA1', department: 'P1' }, subject.org_codes)
    end

    test 'a form counts as searchable once any one piece of metadata is set' do
      assert_not template(name: 'Bare').searchable_metadata?
      assert template(form_type: 'Request').searchable_metadata?
      assert template(agency_id: 'AA1').searchable_metadata?
      assert template(tags: 'safety').searchable_metadata?
    end

    test 'a description alone does not make a form searchable by facet' do
      # There is no description facet — it is matched by the text box, which
      # every form takes part in whether or not it has been tagged.
      assert_not template(description: 'Anything at all').searchable_metadata?
    end
  end
end
