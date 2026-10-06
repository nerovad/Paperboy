# frozen_string_literal: true

module Paperboy
  module FormSeed
    # The workflow half of a form definition: its statuses, routing steps,
    # notification emails, email rules and copy recipients. Dev is the source of
    # truth for all five, so unlike fields they are not merely added to -- for
    # every list db/forms.yml carries, this database is made to match it, and a
    # row here that the file does not name is removed.
    #
    # A form the file describes without one of these keys (a db/forms.yml dumped
    # before they travelled) keeps whatever that list holds here.
    #
    # Rows are matched on what names them in every database: a status by its
    # key, a routing step by its step number, an email by its kind. Email rules
    # and copy recipients have nothing of the sort, so they are matched by
    # their place in the list. Rows are updated where they stand rather than
    # deleted and rebuilt, so a submission in flight keeps its status and step.
    #
    # group_id is the one column that means nothing outside its own database.
    # It is dumped as the group's name and rewritten on sync, the same way a
    # field's restricted_to_group is. employee_id names a GSABSS row, shared by
    # all three, and travels as it stands.
    #
    # form_template_routing_steps.form_template_status_id is not carried:
    # nothing in the app writes it.
    #
    # A routing step with several routes carries them under its own `routes`
    # key, in order, each with its group dumped by name like the step's own.
    # They are replaced as a list whenever they differ: a route has no key of
    # its own, and nothing points at one (a submission's tasks copy theirs).
    module Workflow
      PARTS = {
        'statuses' => { label: 'status', key: 'key', order: %i[position id],
                        columns: %w[name category position is_initial is_end auto_generated] },
        'routing_steps' => { label: 'routing step', key: 'step_number', order: %i[step_number id], group: true,
                             columns: %w[routing_type employee_id org_filter_level authorization_service_type
                                         display_name approve_button_label deny_button_label condition_field_name
                                         condition_operator condition_value inbox_buttons complete_on_edit
                                         completion_rule deny_rule],
                             routes: true },
        'emails' => { label: 'email', key: 'kind', order: %i[kind id], columns: %w[subject body] },
        'email_steps' => { label: 'email rule', order: %i[position id], group: true,
                           columns: %w[trigger_event recipient_type employee_id authorization_service_type
                                       custom_email recipient_field_name routing_step_number attach_pdf
                                       attach_media position] },
        'copy_recipients' => { label: 'copy recipient', order: %i[position id], group: true,
                               columns: %w[recipient_type trigger_event employee_id authorization_service_type
                                           position] }
      }.freeze

      module_function

      # Every list is written even when empty: an empty list says dev has none,
      # which a missing key does not.
      def dump(template, groups)
        PARTS.to_h do |name, part|
          [name, records(template, name, part).map { |record| dump_row(record, part, groups) }]
        end
      end

      def dump_row(record, part, groups)
        row = record.slice(*[part[:key], *part[:columns]].compact).to_h
        row['group'] = groups[record.group_id] if part[:group]
        row['routes'] = record.routes.map { |route| dump_route(route, groups) }.presence if part[:routes]
        FormSeed.plain(row).compact
      end

      # group_id travels as the group's name; the rest mean the same everywhere.
      def dump_route(route, groups)
        route.slice(*Forms::TemplateStepRoute::COLUMNS - ['group_id']).to_h
             .merge('group' => groups[route.group_id]).compact
      end

      def records(template, name, part)
        template.public_send(name).reorder(*part[:order]).to_a
      end

      # Returns change lines. `template` is nil on a dry run for a form that
      # does not exist here yet, when every row the file names is an addition.
      def sync(template, class_name, row, dry:)
        PARTS.flat_map do |name, part|
          next [] unless row.key?(name)

          sync_part(template, class_name, name, part, Array(row[name]), dry: dry)
        end
      end

      def sync_part(template, class_name, name, part, rows, dry:)
        existing = template ? index(records(template, name, part), part) : {}
        wanted = index(rows, part)
        log = wanted.flat_map do |key, row|
          title = "#{class_name} #{part[:label]} #{key}"
          lines = upsert(template, name, existing[key], row, title, part.merge(name: name), dry: dry)
          part[:routes] ? lines + sync_routes(template, key, row, title, dry: dry) : lines
        end
        log + (existing.keys - wanted.keys).map do |key|
          existing[key].destroy! unless dry
          "- #{class_name} #{part[:label]} #{key}"
        end
      end

      # By natural key where the part has one, else by place in the list.
      def index(rows, part)
        rows.each_with_index.to_h do |row, position|
          [part[:key] ? row[part[:key]].to_s : (position + 1).to_s, row]
        end
      end

      def upsert(template, name, record, row, title, part, dry:)
        attrs, refusal = attributes(row, part)
        return ["! #{title}: #{refusal} -- held back"] if refusal

        changed = record ? attrs.reject { |column, value| record.public_send(column) == value } : attrs.compact
        return [] if changed.empty?

        line = record ? "~ #{title}: #{changed.keys.join(', ')}" : "+ #{title}"
        return [line] if dry

        record ||= template.public_send(name).build
        record.assign_attributes(changed)
        Sync.save(record) ? [line] : ["! #{title}: #{record.errors.full_messages.join('; ')}"]
      end

      # Makes a routing step's routes match the file's. The step is looked up
      # again rather than handed over, since upsert may only just have made it.
      def sync_routes(template, step_number, row, title, dry:)
        wanted, refusal = route_rows(Array(row['routes']))
        return ["! #{title} routes: #{refusal} -- held back"] if refusal

        step = template&.routing_steps&.find_by(step_number: step_number)
        current = step ? step.routes.map { |route| route.slice(*Forms::TemplateStepRoute::COLUMNS).to_h } : []
        return [] if current == wanted
        return ["~ #{title}: routes"] if dry
        return [] unless step

        step.routes.destroy_all
        wanted.each_with_index { |attrs, position| step.routes.create!(attrs.merge('position' => position)) }
        ["~ #{title}: routes"]
      end

      def route_rows(rows)
        missing = nil
        attrs = rows.map do |row|
          name = row['group']
          group = Group.find_by(group_name: name) if name.present?
          missing ||= name if name.present? && group.nil?
          Forms::TemplateStepRoute::COLUMNS.index_with { |column| row[column] }.merge('group_id' => group&.id)
        end
        [attrs, missing && "group #{missing} is not a group in this database"]
      end

      # Every column the part carries, so one the file leaves out goes back to
      # its default rather than being kept: dev blanking a step's condition has
      # to blank it here.
      def attributes(row, part)
        defaults = Forms::Template.reflect_on_association(part[:name]).klass.column_defaults
        attrs = [part[:key], *part[:columns]].compact.index_with { |column| row.fetch(column) { defaults[column] } }
        return [attrs, nil] unless part[:group]

        name = row['group']
        group = Group.find_by(group_name: name) if name.present?
        return [attrs, "group #{name} is not a group in this database"] if name.present? && group.nil?

        [attrs.merge('group_id' => group&.id), nil]
      end
    end
  end
end
