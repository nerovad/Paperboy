# app/helpers/application_helper.rb
module ApplicationHelper
  def syntax_highlight(source, language: nil, filename: nil)
    lexer = Rouge::Lexer.find_fancy(language || filename, source) || Rouge::Lexers::PlainText
    formatter = Rouge::Formatters::HTML.new(css_class: "highlight")

    formatter.format(lexer.lex(source.to_s)).html_safe
  end

  def current_user
    session[:user]
  end

  def format_phone(digits)
    d = digits.to_s.gsub(/\D/, "")
    return digits if d.length != 10
    "#{d[0, 3]}-#{d[3, 3]}-#{d[6, 4]}"
  end

  def format_pst(time, format: :short)
    return nil unless time
    l(time.in_time_zone("Pacific Time (US & Canada)"), format: format)
  end

  def environment_badge(host: request.host, rails_env: Rails.env)
    env_name = rails_env.to_s

    if localhost_host?(host)
      { label: "LOCALHOST", css_class: "is-localhost" }
    elsif env_name == "development"
      { label: "Development", css_class: "is-development" }
    elsif env_name == "staging"
      { label: "Stage", css_class: "is-staging" }
    end
  end

  def system_admin?
    current_user_group_names.include?("system_admins")
  end


  def fetch_acl_groups
    Group.order(:Group_Name).pluck(:Group_Name, :GroupID)
  rescue
    []
  end

  # Catalog of dynamic forms and their fields, for the column customizer's
  # "add a field from a form" picker. Shape:
  #   { "Leave Of Absence" => { "class_name" => "LeaveOfAbsenceForm",
  #       "fields" => [{ "name" => "reason", "label" => "Leave Reason" }, ...] } }
  # Only fields backed by a real column on the form's table are offered
  # (excludes media/information fields and anything not persisted as a column).
  def table_field_catalog
    non_display = %w[media_attachment information]
    catalog = {}

    FormTemplate.includes(:form_fields).order(:name).each do |template|
      klass = template.class_name.safe_constantize
      next unless klass && klass.respond_to?(:column_names)
      columns = klass.column_names

      fields = template.form_fields
                       .reject { |f| non_display.include?(f.field_type) }
                       .select { |f| columns.include?(f.field_name.to_s) }
                       .map { |f| { "name" => f.field_name, "label" => (f.label.presence || f.field_name.to_s.tr("_", " ").titleize) } }
                       .uniq { |h| h["name"] }

      next if fields.empty?
      catalog[template.name] = { "class_name" => template.class_name, "fields" => fields }
    end

    catalog
  rescue => e
    Rails.logger.warn("table_field_catalog failed: #{e.class}: #{e.message}")
    {}
  end

  private

  def localhost_host?(host)
    [ "localhost", "127.0.0.1", "::1" ].include?(host.to_s)
  end
end
