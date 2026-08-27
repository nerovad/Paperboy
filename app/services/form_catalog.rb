# frozen_string_literal: true

# Every blank form a person may fill out, paired with the route that opens it.
#
# This was sixty lines of ERB at the top of the Paperboy sidebar until the
# command palette needed the same list. The palette answers `:` from any app —
# Billing, COA, DAM — none of which render that sidebar, so the list had to
# leave the one partial that could build it.
#
#   catalog = FormCatalog.new(admin: system_admin?,
#                             permitted_keys: current_user_form_permission_keys)
#   catalog.forms               # [["Leave of Absence", "/leave_of_absence_forms/new"], …]
#   catalog.template_for(name)  # the Forms::Template behind a link, or nil
#   catalog.finder              # FormFinder over exactly those templates
#
# Every list is filtered by the ACL first, so nothing downstream — the sidebar's
# links, Advanced Search's facets, the palette's results — can offer a form the
# viewer may not open.
class FormCatalog
  include Rails.application.routes.url_helpers

  # Forms that predate Forms::Template and still have hand-written routes.
  # `key` is what the permission set calls them; a template-backed form is
  # keyed by its record id instead.
  LEGACY_FORMS = [
    { name: 'Creative Job Request', key: 'creative_job_request', route: :new_creative_job_request_path },
    { name: 'Leave of Absence', key: 'leave_of_absence', route: :new_leave_of_absence_form_path },
    { name: 'Workplace Violence', key: 'workplace_violence', route: :new_workplace_violence_form_path },
    { name: 'Notice of Change', key: 'notice_of_change', route: :new_notice_of_change_form_path }
  ].freeze

  def initialize(admin:, permitted_keys:)
    @admin = admin
    @permitted_keys = permitted_keys
  end

  # [[name, path], …], alphabetical — the order the sidebar and the palette
  # both render in.
  def forms
    @forms ||= (legacy_forms + template_forms).sort_by(&:first)
  end

  # The template a link's search metadata comes from. Legacy forms without a
  # template row return nil and search on their name alone.
  def template_for(name)
    templates_by_name[name]
  end

  # The metadata a search row carries, in the shape MATCH_SOURCES reads it in
  # sidebar_search_controller.js. A legacy form with no template row searches
  # on its name alone.
  def search_data(name)
    template = template_for(name)

    {
      fields: template ? template.form_fields.map(&:label).join(', ') : '',
      tags: template&.tags_array&.join(', ') || '',
      number: template&.form_number.to_s,
      description: template&.description.to_s
    }
  end

  # What Advanced Search filters on. Only the sidebar renders these — the
  # palette matches text and has no facet panel.
  def facet_data(name)
    template = template_for(name)

    {
      form_type: template&.form_type.to_s,
      agency: template&.agency_id.to_s,
      division: template&.division_id.to_s,
      department: template&.department_id.to_s,
      unit: template&.unit_id.to_s
    }
  end

  # Facets built from the templates behind the links actually rendered, so
  # Advanced Search can never offer a choice that finds nothing.
  def finder
    @finder ||= FormFinder.new(forms.filter_map { |name, _| templates_by_name[name] })
  end

  private

  attr_reader :admin, :permitted_keys

  def legacy_forms
    @legacy_forms ||= LEGACY_FORMS.filter_map do |form|
      [form[:name], public_send(form[:route])] if permitted?(form[:key])
    end
  end

  def template_forms
    legacy_names = legacy_forms.map(&:first)

    templates_by_name.each_value.filter_map do |template|
      next if legacy_names.include?(template.name)
      next unless permitted?(template.id.to_s)

      path = path_for(template)
      [template.name, path] if path
    end
  end

  # Archived templates stay out of both lists but remain in Manage Form
  # Templates.
  def templates_by_name
    @templates_by_name ||= Forms::Template.active.includes(:form_fields).index_by(&:name)
  end

  def permitted?(key)
    admin || permitted_keys&.include?(key)
  end

  # The standard `new_<file_name>_path` convention first, then the base name
  # for the older templates whose routes never took the _form suffix
  # (critical_information_reportings). A template with neither is not linkable.
  def path_for(template)
    public_send("new_#{template.file_name}_path")
  rescue NoMethodError
    begin
      public_send("new_#{template.file_name.chomp('_form')}_path")
    rescue NoMethodError
      nil
    end
  end
end
