# Renders an admin-authored email subject/body by substituting {{token}}
# placeholders with values pulled from a form submission. Pure string
# substitution — never evaluates the template as code.
#
# Supported tokens:
#   {{submitter_name}}   {{submitter_email}}   {{form_name}}
#   {{status_label}}     {{deny_reason}}       {{field.<field_name>}}
# Unknown tokens render as an empty string.
class FormEmailRenderer
  TOKEN_PATTERN = /\{\{\s*([\w.]+)\s*\}\}/

  def self.render(template_string, submission)
    return "" if template_string.blank?

    template_string.gsub(TOKEN_PATTERN) do
      token_value(Regexp.last_match(1), submission).to_s
    end
  end

  def self.token_value(token, submission)
    if token.start_with?("field.")
      field_name = token.sub("field.", "")
      return submission.respond_to?(field_name) ? submission.public_send(field_name) : ""
    end

    case token
    when "submitter_name"  then submission.try(:name)
    when "submitter_email" then submission.try(:email)
    when "form_name"       then form_name(submission)
    when "status_label"    then submission.try(:status_label)
    when "deny_reason"     then submission.try(:deny_reason) || submission.try(:denial_reason)
    else ""
    end
  rescue StandardError
    ""
  end

  def self.form_name(submission)
    submission.try(:form_template)&.name || submission.class.name.underscore.humanize.titleize
  rescue StandardError
    submission.class.name
  end
end
