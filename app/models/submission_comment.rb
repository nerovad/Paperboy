# frozen_string_literal: true

# One entry in a submission's comment thread: text, files, or both.
#
# Every form has a thread and nobody switches it on -- see the Submission
# comments section of AGENTS.md. Who may read and post is not decided here:
# SubmissionCommentsController asks Forms::SubmissionAccess, the same check
# that gates opening the submission.
#
# A comment is not an edit. It writes nothing to record_edits or
# status_changes, and it does not touch the submission's updated_at.
class SubmissionComment < ApplicationRecord
  MAX_BODY_LENGTH = 5000
  MAX_FILES = 5
  MAX_FILE_SIZE = 10.megabytes

  # Extension => content type. The file picker is limited to the extensions
  # and the model checks the types, which Active Storage reads from the bytes
  # rather than from what the browser claimed.
  FILE_TYPES = {
    '.jpg' => 'image/jpeg',
    '.jpeg' => 'image/jpeg',
    '.png' => 'image/png',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.heic' => 'image/heic',
    '.heif' => 'image/heif',
    '.pdf' => 'application/pdf',
    '.txt' => 'text/plain',
    '.csv' => 'text/csv',
    '.doc' => 'application/msword',
    '.docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.xls' => 'application/vnd.ms-excel',
    '.xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    '.ppt' => 'application/vnd.ms-powerpoint',
    '.pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
  }.freeze
  FILE_TYPE_LABEL = 'an image, PDF, text, CSV, Word, Excel or PowerPoint file'

  belongs_to :commentable, polymorphic: true
  has_many_attached :files

  before_validation { self.body = body.to_s.strip.presence }

  validates :body, length: { maximum: MAX_BODY_LENGTH }
  validate :text_or_files
  validate :acceptable_files

  after_create_commit :notify_subscribers

  scope :chronological, -> { order(:created_at, :id) }
  scope :on, ->(record) { where(commentable_type: record.class.name, commentable_id: record.id) }

  # Whether records of this class carry a thread: the hand-written inbox forms
  # and anything the form builder generated. Keeps the type param from pointing
  # a thread at an arbitrary table.
  def self.commentable_class?(klass)
    return false unless klass.is_a?(Class) && klass < ApplicationRecord

    InboxHelper::HARDCODED_FORM_TYPES.include?(klass.name) || Forms::Template.exists?(class_name: klass.name)
  end

  # { [class name, id] => comment count } for a page of submissions, in one
  # query however many form types the page mixes. Rows with no comments are
  # absent.
  def self.counts_for(records)
    records = Array(records)
    return {} if records.empty?

    where(commentable_type: records.map { |record| record.class.name }.uniq,
          commentable_id: records.map(&:id).uniq)
      .group(:commentable_type, :commentable_id).count
  end

  def self.file_accept = FILE_TYPES.keys.join(',')

  def authored_by?(employee_id)
    author_id.present? && author_id.to_s == employee_id.to_s
  end

  def author_label = author_name.presence || 'An unrecorded user'

  private

  def text_or_files
    return if body.present? || files.attached?

    errors.add(:base, 'Write a comment or attach a file')
  end

  def acceptable_files
    return unless files.attached?

    errors.add(:files, "are limited to #{MAX_FILES} per comment") if files.size > MAX_FILES
    files.each do |file|
      name = file.filename.to_s
      errors.add(:files, "#{name} must be #{FILE_TYPE_LABEL}") unless FILE_TYPES.value?(file.content_type)
      errors.add(:files, "#{name} must be smaller than 10MB") if file.byte_size > MAX_FILE_SIZE
    end
  end

  # Immediate mail for everyone following comments on this form, except the
  # person who just wrote it. Digest subscribers are picked up later by
  # Forms::SubscriptionDigest, which reads this table for its window.
  def notify_subscribers
    recipient_ids = Forms::Subscription.recipient_ids_for(
      form_type: commentable_type, event: 'comment_added', delivery_mode: Forms::Subscription::IMMEDIATE
    )

    (recipient_ids - [author_id.to_s]).each do |employee_id|
      FormSubscriptionMailer.comment(id, employee_id).deliver_later
    end
  rescue StandardError => e
    Rails.logger.warn("comment dispatch failed for #{commentable_type} ##{commentable_id}: #{e.message}")
  end
end
