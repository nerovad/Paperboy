# frozen_string_literal: true

require 'test_helper'

# A repeating section's rows are saved through nested attributes, so every
# field in the section has to be in the generated controller's permit list.
# A field that joins an existing section once rendered in the form and was
# then dropped by strong parameters on submit, because the section's entry
# was already present and left alone.
class FormTemplatesSectionParamsTest < ActiveSupport::TestCase
  Member = Struct.new(:field_name, :dropdown, keyword_init: true) do
    def choices_dropdown? = dropdown
  end
  Section = Struct.new(:section_association_name, :section_members, keyword_init: true)
  Template = Struct.new(:file_name, :repeating_sections, keyword_init: true)

  CONTROLLER = <<~RUBY
    # Generated controller for TeleworkLogForm
    class TeleworkLogFormsController < Forms::BaseController
      private

      def telework_log_form_params
        params.require(:telework_log_form).permit(
          :total_hours,
          telework_log_form_work_performeds_attributes: %i[id _destroy work_performed],
          telework_log_form_hours_attributes: %i[id _destroy hours]
        )
      end
    end
  RUBY

  def inject(content, sections)
    template = Template.new(file_name: 'telework_log_form', repeating_sections: sections)
    FormTemplatesController.new.send(:inject_section_params, content, template)
    content
  end

  def member(name, dropdown: false) = Member.new(field_name: name, dropdown: dropdown)

  test 'a field that joins an existing section is added to its permit entry' do
    section = Section.new(section_association_name: 'telework_log_form_work_performeds',
                          section_members: [member('work_performed'), member('hours')])

    content = inject(CONTROLLER.dup, [section])

    assert_includes content, 'telework_log_form_work_performeds_attributes: %i[id _destroy work_performed hours]'
    assert_equal 1, content.scan('telework_log_form_work_performeds_attributes:').size
    # A key that merely ends the same way is not mistaken for the section.
    assert_includes content, 'telework_log_form_hours_attributes: %i[id _destroy hours]'
  end

  test 'an entry with a nested dropdown list, wrapped over lines, is replaced whole' do
    content = CONTROLLER.sub(
      'telework_log_form_work_performeds_attributes: %i[id _destroy work_performed]',
      "telework_log_form_work_performeds_attributes: [:id, :_destroy,\n            { tags: [] }]"
    )
    section = Section.new(section_association_name: 'telework_log_form_work_performeds',
                          section_members: [member('work_performed'), member('tags', dropdown: true)])

    content = inject(content, [section])

    assert_includes content,
                    'telework_log_form_work_performeds_attributes: [:id, :_destroy, :work_performed, { tags: [] }],'
  end

  test 'a new section is still appended to the permit list' do
    section = Section.new(section_association_name: 'telework_log_form_breaks',
                          section_members: [member('break_start')])

    content = inject(CONTROLLER.dup, [section])

    assert_match(/telework_log_form_hours_attributes: %i\[id _destroy hours\],\n\s+telework_log_form_breaks_attributes: %i\[id _destroy break_start\]\n\s+\)/,
                 content)
  end
end
