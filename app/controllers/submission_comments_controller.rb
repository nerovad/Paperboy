# frozen_string_literal: true

# A submission's comment thread: read it, add to it, download what was attached
# to it, remove an entry.
#
# The thread is one HTML fragment (submission_comments/_thread) that carries
# its own form. The inbox fetches it into the history modal; a submission's
# page renders it inline. Either way the comment-thread Stimulus controller
# posts the form and swaps in the fragment this controller answers with, so
# there is one template and no page reload.
#
# Addressed by class name and id like SubmissionHistoriesController, because
# the inbox lists every form type in one table.
#
# Every action answers to Forms::SubmissionAccess: whoever may open the
# submission may read its thread, post to it and download its files, and
# nobody else may do any of the three.
class SubmissionCommentsController < ApplicationController
  def index
    record = commentable
    return if performed?

    render_thread(record)
  end

  def create
    record = commentable
    return if performed?

    comment = SubmissionComment.new(comment_params.merge(commentable: record, **author))
    saved = comment.save
    return render_thread(record, draft: saved ? nil : comment, status: saved ? :ok : :unprocessable_content) if request.xhr?

    redirect_back_or_to inbox_queue_path, (saved ? :notice : :alert) => (saved ? 'Comment added.' : comment.errors.full_messages.to_sentence)
  end

  def destroy
    comment = viewable_comment
    return if performed?
    return head :forbidden unless helpers.can_delete_comment?(comment)

    comment.destroy
    return render_thread(comment.commentable) if request.xhr?

    redirect_back_or_to inbox_queue_path, notice: 'Comment removed.'
  end

  # Streamed through the app rather than redirected to an Active Storage URL,
  # which would keep working for anyone it was forwarded to. Always a
  # download: these are files strangers to the server uploaded.
  def attachment
    comment = viewable_comment
    return if performed?

    file = comment.files.find_by(id: params[:attachment_id])
    return head :not_found unless file

    send_data file.download, filename: file.filename.to_s, type: file.content_type, disposition: 'attachment'
  end

  private

  # The submission being discussed, or nil with the response already sent.
  def commentable
    klass = application_record_class_named(params[:type])
    return head :not_found unless SubmissionComment.commentable_class?(klass)

    record = klass.find(params[:id])
    return head :forbidden unless helpers.can_view_submission?(record)

    record
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  # A comment whose submission the viewer may open, or nil with the response
  # already sent. A comment left behind by a deleted submission is not found.
  def viewable_comment
    comment = SubmissionComment.find(params[:id])
    record = comment.commentable
    return head :not_found unless record
    return head :forbidden unless helpers.can_view_submission?(record)

    comment
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def render_thread(record, draft: nil, status: :ok)
    render partial: 'submission_comments/thread',
           locals: { record: record, comments: SubmissionComment.on(record).chronological.with_attached_files.to_a,
                     draft: draft },
           layout: false, status: status
  end

  def comment_params
    permitted = params.fetch(:submission_comment, {}).permit(:body, files: [])
    permitted[:files] = Array(permitted[:files]).compact_blank
    permitted
  end

  def author
    user = session[:user] || {}
    { author_id: user['employee_id'].to_s.presence,
      author_name: [user['first_name'], user['last_name']].compact_blank.join(' ').presence }
  end
end
