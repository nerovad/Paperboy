# frozen_string_literal: true

# Renders an admin-authored email subject/body by substituting {{token}}
# placeholders with values pulled from a form submission. Pure string
# substitution — never evaluates the template as code.
#
# Supported tokens:
#   {{submitter_name}}   {{submitter_email}}   {{form_name}}   {{status_label}}
#   {{deny_reason}}      {{reference}}         {{url}}         {{submitted_at}}
#   {{link}}             a button that opens the submission (plain address in a subject)
#   {{field.<column>}}   a column on the form, with org and employee ids named
#   {{recipient_first_name}}  whoever this copy of the email is addressed to
#   {{approval_step}}    the step an Awaiting Approval email is about
#   {{from_status}} {{to_status}} {{changed_by}}  the latest status change, or the edit
#   {{changes}}          a table of the fields an edit changed
# Unknown tokens render as an empty string.
#
# Callers pass what only they know (the recipient, the step, the edits) as
# `context`; everything else is read off the submission.
class FormEmailRenderer
  TOKEN_PATTERN = /\{\{\s*([\w.]+)\s*\}\}/
  BLOCK_TOKENS = %w[link changes].freeze
  TIME_FORMAT = '%b %d, %Y %I:%M %p'

  # Plain text: subjects, and anywhere HTML would be wrong.
  def self.render(template_string, submission, context = {})
    return '' if template_string.blank?

    new(submission, context).text(template_string)
  end

  # An email body. Token values are escaped, line breaks become paragraphs, and
  # the block tokens are swapped in afterwards so their markup is our own.
  def self.render_html(template_string, submission, context = {})
    return ''.html_safe if template_string.blank?

    new(submission, context).html(template_string)
  end

  def self.form_name(submission)
    submission.try(:form_template)&.name || submission.class.name.underscore.humanize.titleize
  rescue StandardError
    submission.class.name
  end

  # Where the submission lives. Falls back to the Submissions list filtered to
  # it for a form without its own page.
  def self.submission_url(submission)
    helpers = Rails.application.routes.url_helpers
    options = ActionMailer::Base.default_url_options
    begin
      raise ArgumentError, 'unsaved submission' unless submission.persisted?

      helpers.polymorphic_url(submission, **options)
    rescue StandardError
      helpers.submissions_url(filter_reference: Forms::Reference.reference_for(submission), **options)
    end
  rescue StandardError
    ''
  end

  def initialize(submission, context = {})
    @submission = submission
    @context = context.to_h.symbolize_keys
  end

  def text(template_string)
    template_string.gsub(TOKEN_PATTERN) { value(Regexp.last_match(1)).to_s }
  end

  def html(template_string)
    blocks = {}
    marked = template_string.gsub(TOKEN_PATTERN) do
      token = Regexp.last_match(1)
      if BLOCK_TOKENS.include?(token)
        marker = "PBEMAILBLOCK#{blocks.size}X"
        blocks[marker] = block(token)
        marker
      else
        ERB::Util.html_escape(value(token).to_s)
      end
    end

    formatted = ApplicationController.helpers.simple_format(marked)
    blocks.each do |marker, markup|
      formatted = formatted.gsub("<p>#{marker}</p>", markup).gsub(marker, markup)
    end
    formatted.html_safe
  end

  private

  attr_reader :submission, :context

  def value(token)
    return field_value(token.delete_prefix('field.')) if token.start_with?('field.')

    reader = Values::READERS[token]
    reader ? instance_exec(&reader) : ''
  rescue StandardError
    ''
  end

  # Only real columns: a token must never reach an arbitrary method on the
  # record. Stored ids come back as names, the way the edit trail shows them.
  def field_value(column)
    return '' unless submission.class.respond_to?(:column_names) && submission.class.column_names.include?(column)

    raw = submission[column]
    raw = raw.compact_blank.join(', ') if raw.is_a?(Array)
    return '' if raw.blank?
    return raw.strftime(TIME_FORMAT) if raw.respond_to?(:strftime) && raw.respond_to?(:hour)

    audit.call(column, raw)
  rescue StandardError
    raw.to_s
  end

  def block(token)
    case token
    when 'link' then Blocks.link(url, reference)
    when 'changes' then Blocks.changes(Array(context[:changes]), audit)
    end.to_s
  end

  def audit
    @audit ||= Forms::AuditValue.new(model: submission.class)
  end

  def reference
    @reference ||= Forms::Reference.reference_for(submission) || "##{submission.id}"
  end

  def url
    @url ||= self.class.submission_url(submission)
  end

  # The transition a status email is about, when the caller didn't say. Read
  # back so the mail shows the labels StatusChange stored, not enum values.
  def status_change
    return @status_change if defined?(@status_change)

    @status_change = submission.try(:status_changes)&.reverse_chronological&.first
  rescue StandardError
    @status_change = nil
  end
end
