# frozen_string_literal: true

require 'test_helper'

# The comment thread carries its own access decision: Comments is not a
# configurable button, so nothing upstream has already decided who sees it.
class SubmissionCommentsControllerTest < ActionController::TestCase # rubocop:disable Metrics/ClassLength
  tests SubmissionCommentsController

  setup do
    @record = probation_transfer_requests(:one)
    session[:user] = { 'employee_id' => '9999', 'email' => 'viewer@example.com',
                       'first_name' => 'Dana', 'last_name' => 'Reyes' }
    @controller.define_singleton_method(:inbox_count) { 0 }
    permit_nothing
  end

  # The fixture is filed by 'MyString' and assigned to nobody, so a viewer with
  # no groups and no ACL grant is somebody Forms::SubmissionAccess refuses.
  def permit_nothing
    @controller.define_singleton_method(:current_user_group_names) { Set.new }
    @controller.define_singleton_method(:current_user_group_ids) { [] }
    @controller.define_singleton_method(:current_user_submission_action_permission_keys) { Set.new }
  end

  def permit_everything
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
  end

  # Somebody who may open the submission without being an admin.
  def sign_in_as_submitter
    session[:user] = session[:user].merge('employee_id' => @record.employee_id)
  end

  def address = { type: @record.class.name, id: @record.id }

  def comment_by(author_id, body: 'An earlier note.')
    SubmissionComment.create!(commentable: @record, author_id: author_id, author_name: 'Somebody Else', body: body)
  end

  def upload(name: 'note.pdf', type: 'application/pdf', bytes: '%PDF-1.4 test')
    tempfile = Tempfile.new(['upload', File.extname(name)])
    tempfile.binmode
    tempfile.write(bytes)
    tempfile.rewind
    Rack::Test::UploadedFile.new(tempfile.path, type, true, original_filename: name)
  end

  test 'a viewer of the submission reads its thread' do
    sign_in_as_submitter
    comment_by('1234', body: 'Waiting on the signed page.')

    get :index, params: address

    assert_response :success
    assert_match 'Waiting on the signed page.', response.body
    assert_match 'Post Comment', response.body
  end

  test 'someone who may not open the submission is refused its thread' do
    comment_by('1234')

    get :index, params: address

    assert_response :forbidden
  end

  test 'a model that is not a form has no thread' do
    permit_everything

    get :index, params: { type: 'Forms::Template', id: 1 }

    assert_response :not_found
  end

  test 'an unknown type has no thread' do
    permit_everything

    get :index, params: { type: 'Object', id: 1 }

    assert_response :not_found
  end

  test 'posting adds a comment in the viewer\'s name and answers with the thread' do
    sign_in_as_submitter

    assert_difference 'SubmissionComment.count', 1 do
      post :create, params: address.merge(submission_comment: { body: 'Here is the page.' }), xhr: true
    end

    comment = SubmissionComment.last
    assert_response :success
    assert_equal @record, comment.commentable
    assert_equal @record.employee_id, comment.author_id
    assert_equal 'Dana Reyes', comment.author_name
    assert_match 'Here is the page.', response.body
  end

  test 'posting keeps the attached file' do
    sign_in_as_submitter

    post :create, params: address.merge(submission_comment: { body: '', files: [upload] }), xhr: true

    assert_response :success
    assert_equal(['note.pdf'], SubmissionComment.last.files.map { |file| file.filename.to_s })
    assert_match 'note.pdf', response.body
  end

  test 'an empty comment is refused and says why' do
    sign_in_as_submitter

    assert_no_difference 'SubmissionComment.count' do
      post :create, params: address.merge(submission_comment: { body: ' ' }), xhr: true
    end

    assert_response :unprocessable_content
    assert_match 'Write a comment or attach a file', response.body
  end

  test 'someone who may not open the submission cannot post to it' do
    assert_no_difference 'SubmissionComment.count' do
      post :create, params: address.merge(submission_comment: { body: 'Let me in.' }), xhr: true
    end

    assert_response :forbidden
  end

  test 'an attachment downloads for a viewer of the submission' do
    sign_in_as_submitter
    comment = comment_by('1234')
    comment.files.attach(io: StringIO.new('%PDF-1.4 test'), filename: 'note.pdf', content_type: 'application/pdf')

    get :attachment, params: { id: comment.id, attachment_id: comment.files.first.id }

    assert_response :success
    assert_equal '%PDF-1.4 test', response.body
    assert_match 'attachment', response.headers['Content-Disposition']
  end

  test 'an attachment is refused to someone who may not open the submission' do
    comment = comment_by('1234')
    comment.files.attach(io: StringIO.new('%PDF-1.4 test'), filename: 'note.pdf', content_type: 'application/pdf')

    get :attachment, params: { id: comment.id, attachment_id: comment.files.first.id }

    assert_response :forbidden
  end

  test 'an attachment id from another comment is not found' do
    sign_in_as_submitter
    comment = comment_by('1234')
    other = SubmissionComment.create!(commentable: probation_transfer_requests(:two), author_id: '1', body: 'x')
    other.files.attach(io: StringIO.new('%PDF-1.4 test'), filename: 'other.pdf', content_type: 'application/pdf')

    get :attachment, params: { id: comment.id, attachment_id: other.files.first.id }

    assert_response :not_found
  end

  test 'an author deletes their own comment' do
    sign_in_as_submitter
    comment = comment_by(@record.employee_id)

    assert_difference 'SubmissionComment.count', -1 do
      delete :destroy, params: { id: comment.id }, xhr: true
    end

    assert_response :success
  end

  test 'a viewer cannot delete somebody else\'s comment' do
    sign_in_as_submitter
    comment = comment_by('1234')

    assert_no_difference 'SubmissionComment.count' do
      delete :destroy, params: { id: comment.id }, xhr: true
    end

    assert_response :forbidden
  end

  test 'a system admin deletes any comment' do
    permit_everything
    comment = comment_by('1234')

    assert_difference 'SubmissionComment.count', -1 do
      delete :destroy, params: { id: comment.id }, xhr: true
    end

    assert_response :success
  end
end # rubocop:enable Metrics/ClassLength
