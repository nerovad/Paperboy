# frozen_string_literal: true

# app/helpers/application_helper.rb
module ApplicationHelper
  def syntax_highlight(source, language: nil, filename: nil)
    lexer = Rouge::Lexer.find_fancy(language || filename, source) || Rouge::Lexers::PlainText
    formatter = Rouge::Formatters::HTML.new(css_class: 'highlight')

    formatter.format(lexer.lex(source.to_s)).html_safe
  end

  def current_user
    session[:user]
  end

  def format_phone(digits)
    d = digits.to_s.gsub(/\D/, '')
    return digits if d.length != 10

    "#{d[0, 3]}-#{d[3, 3]}-#{d[6, 4]}"
  end

  def format_pst(time, format: :short)
    return nil unless time

    l(time.in_time_zone('Pacific Time (US & Canada)'), format: format)
  end

  def environment_badge(host: request.host, rails_env: Rails.env)
    env_name = rails_env.to_s

    if localhost_host?(host)
      { label: 'LOCALHOST', css_class: 'is-localhost' }
    elsif env_name == 'development'
      { label: 'Development', css_class: 'is-development' }
    elsif env_name == 'staging'
      { label: 'Stage', css_class: 'is-staging' }
    end
  end

  def system_admin?
    current_user_group_names.include?('system_admins')
  end

  # The sub-applications reachable from the sidebar app switcher. Each entry
  # is { key:, label:, path: }; entries the current user may not see are
  # filtered out. Paperboy is the always-available base app; the secondary
  # apps are gated by the ACL "Applications" section (system admins bypass),
  # matching the profile-dropdown/form permission model.
  def paperboy_apps
    apps = [{ key: 'paperboy', label: 'Paperboy', path: root_path }]
    apps << { key: 'data_runner', label: 'Data Runner', path: data_runner_root_path } if can_access_app?('data_runner')
    apps << { key: 'coa', label: 'Chart of Accounts', path: coa_root_path } if can_access_app?('coa')
    apps
  end

  # Whether the current user may reach an app-switcher sub-application. System
  # admins see everything; everyone else needs an ACL "application" grant for
  # the given key (via group or org-level permission).
  def can_access_app?(key)
    system_admin? || current_user_application_permission_keys.include?(key)
  end

  # Homepage slideshow pictures for each sub-app. These are intentionally
  # kept separate so every app can show its own images: drop the files in
  # app/assets/images and swap the filenames below. (Currently pointed at
  # existing Ventura images as placeholders.)
  def data_runner_home_images
    [
      { src: 'VenturaCityHall.png', alt: 'Data Runner' },
      { src: 'VenturaPier.png', alt: 'Data Runner' }
    ]
  end

  def coa_home_images
    [
      { src: 'VenturaCross.png', alt: 'Chart of Accounts' },
      { src: 'VenturaCityHall.png', alt: 'Chart of Accounts' }
    ]
  end

  # Which sub-application the current request belongs to, keyed to
  # +paperboy_apps+. Defaults to Paperboy for everything outside the
  # data_runner/ and coa/ controller namespaces.
  def current_app_key
    if controller_path.start_with?('data_runner/')
      'data_runner'
    elsif controller_path.start_with?('coa/')
      'coa'
    else
      'paperboy'
    end
  end

  def fetch_acl_groups
    Group.order(:Group_Name).pluck(:Group_Name, :GroupID)
  rescue StandardError
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
      next unless klass.respond_to?(:column_names)

      columns = klass.column_names

      fields = template.form_fields
                       .reject { |f| non_display.include?(f.field_type) }
                       .select { |f| columns.include?(f.field_name.to_s) }
                       .map { |f| { 'name' => f.field_name, 'label' => f.label.presence || f.field_name.to_s.tr('_', ' ').titleize } }
                       .uniq { |h| h['name'] }

      next if fields.empty?

      catalog[template.name] = { 'class_name' => template.class_name, 'fields' => fields }
    end

    catalog
  rescue StandardError => e
    Rails.logger.warn("table_field_catalog failed: #{e.class}: #{e.message}")
    {}
  end

  private

  def localhost_host?(host)
    ['localhost', '127.0.0.1', '::1'].include?(host.to_s)
  end
end
