# Delivers a single configurable workflow email defined by a FormTemplateEmailStep.
# Invoked (via deliver_later) from TrackableStatus when a form is submitted or a
# routing step is approved/denied. Loads everything by id so async delivery sees
# committed data.
class FormWorkflowMailer < ApplicationMailer
  def notify(email_step_id, submission_class, submission_id)
    email_step = FormTemplateEmailStep.find_by(id: email_step_id)
    return if email_step.nil?

    submission = resolve_submission(submission_class, submission_id)
    return if submission.nil?

    recipients = email_step.resolve_recipient_emails(submission)
    return if recipients.blank?

    add_pdf_attachment(email_step, submission)   if email_step.attach_pdf
    add_media_attachments(submission)            if email_step.attach_media

    @body_html = email_step.render_body(submission)
    subject = email_step.render_subject(submission).presence ||
              "#{FormEmailRenderer.form_name(submission)} notification"

    mail(to: recipients, subject: subject)
  end

  private

  def resolve_submission(submission_class, submission_id)
    submission_class.to_s.constantize.find_by(id: submission_id)
  rescue NameError
    nil
  end

  def add_pdf_attachment(email_step, submission)
    template = email_step.form_template
    generator = pdf_generator_for(template.class_name)
    return unless generator

    attachments["#{template.class_name}_#{submission.id}.pdf"] = {
      mime_type: "application/pdf",
      content: generator.generate(submission)
    }
  rescue StandardError => e
    Rails.logger.warn("FormWorkflowMailer: PDF attachment skipped — #{e.message}")
  end

  # Form-builder forms use "<ClassName>PdfGenerator" (e.g. BikeLockerFormPdfGenerator);
  # some legacy forms drop the trailing "Form". Try both.
  def pdf_generator_for(class_name)
    candidates = ["#{class_name}PdfGenerator", "#{class_name.sub(/Form\z/, '')}PdfGenerator"].uniq
    candidates.filter_map { |name| name.safe_constantize }.first
  end

  # Attach every file from the submission's media_attachment fields.
  def add_media_attachments(submission)
    template = submission.try(:form_template)
    return unless template

    media_fields = template.form_fields.where(field_type: "media_attachment")
    media_fields.each do |field|
      next unless submission.respond_to?(field.field_name)
      Array(submission.public_send(field.field_name)).each do |attached|
        blob = attached.respond_to?(:blob) ? attached.blob : attached
        attachments[blob.filename.to_s] = blob.download
      end
    end
  rescue StandardError => e
    Rails.logger.warn("FormWorkflowMailer: media attachments skipped — #{e.message}")
  end
end
