# frozen_string_literal: true

# Each form's email wording moves out of its individual email rules and into
# one place per form: four emails (new submission, awaiting approval, field
# edited, status changed) that every notification for the form uses — email
# rules, inbox notifications and form subscriptions alike. A rule keeps who and
# when; the wording comes from here.
#
# Rules that already carried their own text hand it to the form first, so a
# form whose rules were worded on Prod still reads the same after the deploy.
# Submission rules seed New Submission; approval and denial rules seed Status
# Changed. Where several rules disagree the earliest wins.
class CreateFormTemplateEmails < ActiveRecord::Migration[8.1]
  class EmailStep < ActiveRecord::Base
    self.table_name = 'form_template_email_steps'
  end

  class TemplateEmail < ActiveRecord::Base
    self.table_name = 'form_template_emails'
  end

  SEEDS = { 'submit' => 'new_submission', 'approved' => 'status_changed', 'denied' => 'status_changed' }.freeze

  def up
    create_table :form_template_emails do |t|
      t.bigint :form_template_id, null: false
      t.string :kind, null: false
      t.string :subject
      t.text :body
      t.timestamps
    end
    add_index :form_template_emails, %i[form_template_id kind], unique: true
    add_foreign_key :form_template_emails, :form_templates

    seed_from_email_steps

    remove_column :form_template_email_steps, :subject
    remove_column :form_template_email_steps, :body
  end

  def down
    add_column :form_template_email_steps, :subject, :string
    add_column :form_template_email_steps, :body, :text
    drop_table :form_template_emails
  end

  private

  def seed_from_email_steps
    EmailStep.reset_column_information
    TemplateEmail.reset_column_information

    EmailStep.where.not(subject: [nil, '']).or(EmailStep.where.not(body: [nil, '']))
             .order(:form_template_id, :position, :id).each do |step|
      kind = SEEDS[step.trigger_event]
      next unless kind
      next if TemplateEmail.exists?(form_template_id: step.form_template_id, kind: kind)

      TemplateEmail.create!(form_template_id: step.form_template_id, kind: kind,
                            subject: step.subject.presence, body: step.body.presence)
    end
  end
end
