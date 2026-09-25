# frozen_string_literal: true

# The wording of one of a form's four notification emails. Who receives an email
# is decided elsewhere — email rules in the form builder, inbox notifications
# and form subscriptions in Settings and on the ACL page — but all of them read
# their subject and body from here, so a form reads the same whoever is told.
#
#   new_submission     a subscriber hears a form was filed; an email rule fires on submit
#   awaiting_approval  an approver has something in their inbox
#   field_edited       a subscriber hears fields changed
#   status_changed     a subscriber hears the status moved; an approve/deny email rule fires
#
# A form that never customized an email, or left a part blank, gets DEFAULTS
# for that part, so every form sends something sensible from day one. Tokens
# are listed in FormEmailRenderer.
module Forms
  class TemplateEmail < ApplicationRecord
    self.table_name = 'form_template_emails'

    def self.model_name = ActiveModel::Name.new(self, nil, 'FormTemplateEmail')
    belongs_to :form_template, class_name: 'Forms::Template'

    KIND_LABELS = {
      'new_submission' => 'New Submission',
      'awaiting_approval' => 'Awaiting Approval',
      'field_edited' => 'Field Edited',
      'status_changed' => 'Status Changed'
    }.freeze
    KINDS = KIND_LABELS.keys.freeze

    KIND_DESCRIPTIONS = {
      'new_submission' => 'Sent to New submission subscribers, and by email rules set to fire on submission.',
      'awaiting_approval' => 'Sent to an approver when this form lands in their inbox, if they switched on Inbox notifications.',
      'field_edited' => 'Sent to Field edited subscribers. {{changes}} lists each field, what it was and what it is now.',
      'status_changed' => 'Sent to Status changed subscribers, and by email rules set to fire on approval or denial.'
    }.freeze

    SUMMARY = <<~TEXT.chomp
      Reference: {{reference}}
      Submitted by: {{submitter_name}}
      Submitted: {{submitted_at}}
      Status: {{status_label}}
    TEXT

    DEFAULTS = {
      'new_submission' => {
        subject: 'New {{form_name}} {{reference}}',
        body: <<~TEXT
          Hello {{recipient_first_name}},

          A new {{form_name}} has been submitted.

          #{SUMMARY}

          {{link}}
        TEXT
      },
      'awaiting_approval' => {
        subject: 'Awaiting your approval: {{form_name}} {{reference}}',
        body: <<~TEXT
          Hello {{recipient_first_name}},

          A {{form_name}} is waiting for your approval.

          #{SUMMARY}
          Approval step: {{approval_step}}

          {{link}}
        TEXT
      },
      'field_edited' => {
        subject: 'Updated: {{form_name}} {{reference}}',
        body: <<~TEXT
          Hello {{recipient_first_name}},

          {{form_name}} {{reference}} has been edited.
          Edited by: {{changed_by}}

          {{changes}}

          {{link}}
        TEXT
      },
      'status_changed' => {
        subject: 'Status changed: {{form_name}} {{reference}}',
        body: <<~TEXT
          Hello {{recipient_first_name}},

          The status of {{form_name}} {{reference}} changed from {{from_status}} to {{to_status}}.
          Changed by: {{changed_by}}

          #{SUMMARY}

          {{link}}
        TEXT
      }
    }.freeze

    validates :kind, inclusion: { in: KINDS }, uniqueness: { scope: :form_template_id }

    # The email of `kind` for the form `submission` belongs to — the saved one,
    # or an unsaved one carrying the defaults when the form has none.
    def self.for(submission, kind)
      template = template_for(submission)
      saved = template&.emails&.find { |email| email.kind == kind.to_s }
      saved || new(form_template: template, kind: kind.to_s)
    end

    # Hand-coded forms answer #form_template themselves; everything else is
    # found by class name, and a form with no template gets the defaults.
    def self.template_for(submission)
      submission.try(:form_template) || Forms::Template.find_by(class_name: submission.class.name)
    rescue StandardError
      nil
    end

    def self.default_subject(kind) = DEFAULTS.fetch(kind.to_s)[:subject]

    def self.default_body(kind) = DEFAULTS.fetch(kind.to_s)[:body]

    def label = KIND_LABELS[kind]

    def description = KIND_DESCRIPTIONS[kind]

    def effective_subject = subject.presence || self.class.default_subject(kind)

    def effective_body = body.presence || self.class.default_body(kind)

    def render_subject(submission, context = {})
      FormEmailRenderer.render(effective_subject, submission, context).squish
    end

    def render_body(submission, context = {})
      FormEmailRenderer.render_html(effective_body, submission, context)
    end
  end
end
