# frozen_string_literal: true

require 'test_helper'

# The placeholders a form's emails are written with. Values come from the
# submission, so the body escapes them, and a placeholder only ever reads a
# column — never an arbitrary method on the record.
class FormEmailRendererTest < ActiveSupport::TestCase
  Edit = Struct.new(:column_name, :old_value, :new_value, :changed_by_name)

  setup do
    @submission = probation_transfer_requests(:one)
  end

  test 'field placeholders read columns off the submission' do
    @submission.update_columns(phone: '805-555-0199')

    assert_equal 'Call 805-555-0199', FormEmailRenderer.render('Call {{field.phone}}', @submission)
  end

  test 'a field placeholder that is not a column reads nothing and calls nothing' do
    assert_equal '[]', FormEmailRenderer.render('[{{field.destroy}}]', @submission)
    assert ProbationTransferRequest.exists?(@submission.id)
  end

  test 'the body escapes submitted values and keeps line breaks' do
    @submission.update_columns(desired_transfer_destination: '<script>x</script>')

    html = FormEmailRenderer.render_html("Where:\n{{field.desired_transfer_destination}}", @submission)

    assert_includes html, '&lt;script&gt;'
    assert_not_includes html, '<script>'
    assert_includes html, '<br'
  end

  test 'link is a button to the submission in a body and a plain address in a subject' do
    reference = Forms::Reference.reference_for(@submission)
    html = FormEmailRenderer.render_html("See below\n\n{{link}}", @submission)

    assert_match %r{href="http://example\.com/probation_transfer_requests/#{@submission.id}"}, html
    assert_includes html, "Open #{reference}"
    assert_equal "Open http://example.com/probation_transfer_requests/#{@submission.id}",
                 FormEmailRenderer.render('Open {{link}}', @submission)
    assert_equal "Re: #{reference}", FormEmailRenderer.render('Re: {{reference}}', @submission)
  end

  test 'changes is a table of what an edit changed' do
    html = FormEmailRenderer.render_html('{{changes}}', @submission,
                                         changes: [Edit.new('phone', '805-555-0100', '805-555-0199')])

    assert_includes html, '<table'
    assert_includes html, 'Phone'
    assert_includes html, '805-555-0100'
    assert_includes html, '805-555-0199'
  end

  test 'context fills what only the caller knows; unknown tokens are blank' do
    text = FormEmailRenderer.render('Hi {{recipient_first_name}}, {{approval_step}}{{nonsense}}', @submission,
                                    recipient_first_name: 'Dana', approval_step: 'Step 1 — Manager')

    assert_equal 'Hi Dana, Step 1 — Manager', text
    assert_equal 'Hello there,', FormEmailRenderer.render('Hello {{recipient_first_name}},', @submission)
  end
end
