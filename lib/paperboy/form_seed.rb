# frozen_string_literal: true

module Paperboy
  # Mirrors the form *definitions* -- form_templates, the form_fields hanging
  # off them and the workflow that runs them -- across Paperboy_Dev / _Stage /
  # _Prod, which are three independent databases. Driven by lib/tasks/forms.rake:
  # forms:dump here, commit db/forms.yml, forms:sync there. This half writes the
  # file; FormSeed::Sync applies it.
  #
  # The form builder writes two things: the .erb views, which reach every
  # environment through git, and these rows, which reach none on their own.
  # That split is why a dropdown configured in dev rendered empty in production,
  # and why a form built in dev, or an email reworded there, never arrived.
  #
  # Dev is the source of truth. A form the file names is created where it is
  # missing, and its template columns, statuses, routing steps, emails, email
  # rules and copy recipients are made to match (see FormSeed::Workflow).
  # Fields alone stay additive -- removing one needs PRUNE=1 -- because the
  # file is a union and a field dropped in dev is still in it.
  #
  # Nothing is matched on an id that a single database owns:
  #   * templates by class_name -- it names a class checked into the repo, while
  #     form_templates.id is an identity column each database allocates alone.
  #   * fields by field_name within their template -- it names the column the
  #     field writes to.
  #   * conditional_field_id and conditional_answer_field_id by the field name
  #     they point at, rewritten to local ids on sync.
  #   * restricted_to_group_id, and group_id on a workflow row, by Group_Name,
  #     the same key db/acl.yml already carries between these three databases.
  #
  # Portable as they stand, and so dumped raw: every employee id and a
  # template's agency/division/department/unit ids all name GSABSS rows, which
  # are shared reference data rather than per-database.
  #
  # Deliberately NOT handled:
  #   * reference_prefix, which has a unique index and is stamped on references
  #     already issued. A new template derives its own, as it does in the builder.
  #   * archived, has_dashboard, metabase_dashboard_id: operational state, set
  #     where the form actually runs.
  #   * form_visibility_grants and subscriptions: who sees or hears about a
  #     submission, granted per environment like the rest of the ACL screens.
  module FormSeed
    PATH = Rails.root.join('db/forms.yml')

    # Field columns that mean the same thing in every database.
    FIELD_COLUMNS = %w[field_type label page_number position required options read_only
                       has_custom_view visible_to_filler restricted_to_type
                       restricted_to_employee_id restricted_to_org_filter_level
                       conditional_values conditional_answer_mappings].freeze

    # Template columns that mean the same thing in every database.
    TEMPLATE_COLUMNS = %w[name page_count page_headers submission_type description
                          form_number form_type agency_id division_id department_id
                          unit_id approval_routing_to approval_employee_id
                          status_transition_mode inbox_buttons tags records_table
                          skip_code_generation].freeze

    # Pointer columns, dumped as the field_name they name rather than as an id.
    LINKS = { 'conditional_field' => 'conditional_field_id',
              'conditional_answer_field' => 'conditional_answer_field_id' }.freeze

    module_function

    def snapshot
      groups = Group.all.to_h { |group| [group.id, group.group_name] }
      { 'forms' => Forms::Template.order(:class_name).map { |template| form_row(template, groups) } }
    end

    def form_row(template, groups)
      fields = Forms::Field.where(form_template_id: template.id).order(:page_number, :position, :id).to_a
      by_id = fields.index_by(&:id)
      # Not compacted: a column dev has blanked has to say so, or sync could
      # not tell it from one an older file never carried.
      { 'class_name' => template.class_name }
        .merge(plain(template.slice(*TEMPLATE_COLUMNS).to_h))
        .merge('fields' => fields.map { |field| field_row(field, by_id, groups) })
        .merge(Workflow.dump(template, groups))
    end

    def field_row(field, by_id, groups)
      row = { 'field_name' => field.field_name }.merge(field.slice(*FIELD_COLUMNS).to_h)
      LINKS.each { |key, column| row[key] = by_id[field.public_send(column)]&.field_name }
      row['restricted_to_group'] = groups[field.restricted_to_group_id]
      plain(row).compact
    end

    # A JSON column comes back as a HashWithIndifferentAccess, and so does
    # anything nested inside it. YAML tags those with their class name and
    # safe_load then refuses the file, so flatten the whole row to ordinary
    # Hash/Array/scalar before it is written.
    def plain(value)
      case value
      when Hash  then value.to_h { |key, nested| [key.to_s, plain(nested)] }
      when Array then value.map { |nested| plain(nested) }
      else value
      end
    end

    def load_file
      raise "#{PATH} not found -- run `bin/rails forms:dump` against dev first." unless PATH.exist?

      YAML.safe_load_file(PATH) || {}
    end

    # Union this environment's forms into what db/forms.yml already holds, so
    # the file can describe every environment at once and a dump from dev never
    # drops a form only prod has. This environment wins where both describe the
    # same field, since you dump from wherever the definitions are authored.
    def merge(file_data, snapshot)
      forms = {}
      (Array(file_data['forms']) + Array(snapshot['forms'])).each do |row|
        key = row['class_name'].to_s
        forms[key] = forms[key] ? merge_form(forms[key], row) : row
      end
      { 'forms' => forms.values.sort_by { |row| row['class_name'].to_s } }
    end

    def merge_form(base, other)
      fields = {}
      (Array(base['fields']) + Array(other['fields'])).each { |field| fields[field['field_name'].to_s] = field }
      other.merge('fields' => fields.values.sort_by { |field| field_order(field) })
    end

    def field_order(field)
      [field['page_number'].to_i, field['position'].to_i, field['field_name'].to_s]
    end
  end
end
