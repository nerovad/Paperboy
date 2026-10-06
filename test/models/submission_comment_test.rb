# frozen_string_literal: true

require 'test_helper'

class SubmissionCommentTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  PTR = 'ProbationTransferRequest'

  setup do
    @record = probation_transfer_requests(:one)
  end

  def build(**attributes)
    SubmissionComment.new({ commentable: @record, author_id: '9999', author_name: 'Dana Reyes' }.merge(attributes))
  end

  def file(name: 'note.pdf', type: 'application/pdf', bytes: '%PDF-1.4 test')
    { io: StringIO.new(bytes), filename: name, content_type: type, identify: false }
  end

  test 'text alone is a comment' do
    assert build(body: 'Please attach the signed page.').save
  end

  test 'a file alone is a comment' do
    comment = build
    comment.files.attach(file)

    assert comment.save
    assert_equal 1, comment.files.count
  end

  test 'neither text nor a file is refused' do
    comment = build(body: "  \n ")

    assert_not comment.save
    assert_includes comment.errors.full_messages, 'Write a comment or attach a file'
  end

  test 'a file of a type that is not listed is refused' do
    comment = build(body: 'see attached')
    comment.files.attach(file(name: 'run.exe', type: 'application/x-msdownload'))

    assert_not comment.save
    assert_match 'run.exe', comment.errors.full_messages.to_sentence
  end

  test 'a file over the size limit is refused' do
    comment = build
    comment.files.attach(file(bytes: 'x' * (SubmissionComment::MAX_FILE_SIZE + 1)))

    assert_not comment.save
    assert_match 'smaller than 10MB', comment.errors.full_messages.to_sentence
  end

  test 'more files than the limit are refused' do
    comment = build
    (SubmissionComment::MAX_FILES + 1).times { |n| comment.files.attach(file(name: "#{n}.pdf")) }

    assert_not comment.save
    assert_match "limited to #{SubmissionComment::MAX_FILES}", comment.errors.full_messages.to_sentence
  end

  test 'commenting leaves the submission and its histories alone' do
    updated_at = @record.updated_at

    assert_no_difference ['RecordEdit.count', 'StatusChange.count'] do
      build(body: 'A note.').save!
    end
    assert_equal updated_at, @record.reload.updated_at
  end

  test 'counts are keyed by class name and id and skip rows with none' do
    other = probation_transfer_requests(:two)
    2.times { build(body: 'hi').save! }

    counts = SubmissionComment.counts_for([@record, other])

    assert_equal({ [PTR, @record.id] => 2 }, counts)
  end

  test 'only form models carry a thread' do
    assert SubmissionComment.commentable_class?(ProbationTransferRequest)
    assert_not SubmissionComment.commentable_class?(Forms::Template)
    assert_not SubmissionComment.commentable_class?(nil)
  end

  test 'immediate comment subscribers are mailed, the author is not' do
    %w[8100 9999].each do |employee_id|
      Forms::Subscription.create!(form_type: PTR, grantee_type: 'employee', employee_id: employee_id,
                                  delivery_mode: Forms::Subscription::IMMEDIATE, notify_comment_added: true)
    end

    assert_enqueued_emails 1 do
      build(body: 'Any update?').save!
    end
  end

  test 'a subscriber following other events is not mailed about a comment' do
    Forms::Subscription.create!(form_type: PTR, grantee_type: 'employee', employee_id: '8100',
                                delivery_mode: Forms::Subscription::IMMEDIATE, notify_edited: true)

    assert_no_enqueued_emails do
      build(body: 'Any update?').save!
    end
  end
end
