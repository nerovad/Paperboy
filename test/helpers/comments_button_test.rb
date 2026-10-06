# frozen_string_literal: true

require 'test_helper'

# The inbox's Comments button: on for every form, and labelled with how many
# comments the row already has.
class CommentsButtonTest < ActionView::TestCase
  helper InboxHelper, SubmissionsHelper

  setup do
    @record = probation_transfer_requests(:one)
  end

  test 'a submission with no comments gets a plain Comments button' do
    render 'inbox/comments_button', submission: @record

    assert_select 'button.btn.info', text: 'Comments'
    assert_select "button[data-history-url='#{inbox_comments_path(type: 'ProbationTransferRequest', id: @record.id)}']"
  end

  test 'the button counts the comments from the page preload' do
    @comment_counts = { ['ProbationTransferRequest', @record.id] => 3 }

    render 'inbox/comments_button', submission: @record

    assert_select "button[data-comment-count-key='ProbationTransferRequest-#{@record.id}']", text: 'Comments (3)'
  end

  test 'a record that is not a form gets no button' do
    render 'inbox/comments_button', submission: Forms::Template.new

    assert_select 'button', count: 0
  end
end
