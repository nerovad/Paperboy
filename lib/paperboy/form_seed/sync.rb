# frozen_string_literal: true

module Paperboy
  module FormSeed
    # Applies db/forms.yml to this database: the forms:sync half of FormSeed.
    #
    # A form the file names is created here when it is missing, and its
    # template columns and workflow are made to match the file (see
    # FormSeed::Workflow). Fields are additive -- one here the file does not
    # mention is left alone unless PRUNE=1 -- and a form here the file does not
    # mention is never touched. Everything runs inside one transaction, and
    # DRY_RUN=1 produces the same log without writing.
    #
    # A row this database cannot hold -- a field whose custom lookup names a
    # table that is not here, a routing step for a group that is not -- fails
    # validation. That is reported as a refusal rather than raised, so one
    # stale definition cannot take a deploy down halfway through.
    module Sync
      module_function

      # Returns a list of human-readable change lines.
      def call(dry:, prune:)
        data = FormSeed.load_file
        Array(data['forms']).flat_map { |row| form(row, dry: dry, prune: prune) }
      end

      def form(row, dry:, prune:)
        class_name = row['class_name'].to_s.strip
        return ['! a form with a blank class_name in db/forms.yml -- skipped'] if class_name.empty?

        template = Forms::Template.find_by(class_name: class_name)
        log = template ? update_template(template, class_name, row, dry: dry) : ["+ form   #{class_name}"]
        template ||= create_template(class_name, row) unless dry
        return [refused(class_name, 'template', template)] if template&.new_record?

        log + fields(template, class_name, Array(row['fields']), dry: dry, prune: prune) +
          Workflow.sync(template, class_name, row, dry: dry)
      end

      # Returned unsaved, with its errors, when this database will not have it.
      def create_template(class_name, row)
        template = Forms::Template.new('class_name' => class_name)
        assign_template(template, row, row.slice(*FormSeed::TEMPLATE_COLUMNS))
        save(template)
        template
      end

      # Only the columns the file carries, so an older db/forms.yml that knows
      # nothing of a column cannot clear it.
      def update_template(template, class_name, row, dry:)
        changed = row.slice(*FormSeed::TEMPLATE_COLUMNS).reject { |column, value| template.public_send(column) == value }
        return [] if changed.empty?

        line = "~ form   #{class_name}: #{changed.keys.join(', ')}"
        return [line] if dry

        assign_template(template, row, changed)
        save(template) ? [line] : [refused(class_name, 'template', template)]
      end

      # The template is saved before its routing steps and statuses are, which
      # an approval form's validations would refuse. pending_routing_steps is
      # how the form builder says they are on their way. A file dumped before
      # routing travelled names none, so such a form falls back to the
      # supervisor, the first thing the builder offers.
      def assign_template(template, row, attributes)
        template.assign_attributes(attributes)
        template.pending_routing_steps = row['routing_steps'].presence
        template.approval_routing_to ||= 'supervisor' if template.requires_legacy_routing?
      end

      def fields(template, class_name, rows, dry:, prune:)
        grouped = template ? Forms::Field.where(form_template_id: template.id).group_by(&:field_name) : {}
        ambiguous = ambiguous_names(grouped, rows)
        existing = grouped.except(*ambiguous).transform_values(&:first)
        wanted = rows.reject { |row| ambiguous.include?(row['field_name'].to_s) }

        log = ambiguous.sort.map { |name| ambiguity(class_name, name) }
        log += wanted.flat_map { |row| upsert(template, class_name, row, existing, dry: dry) }
        # Second pass: a pointer can name a field created moments ago, so links
        # are resolved only once every field the file names exists.
        log += wanted.flat_map { |row| relink(class_name, row, existing, dry: dry) }
        return log unless prune && template

        log + prune_extras(class_name, wanted, existing, dry: dry)
      end

      # field_name is the only key that names the same field in two databases,
      # so two fields sharing one inside a template cannot be told apart here --
      # PcardRequestForm carries six such pairs across its pages. Syncing them
      # would copy one field's definition onto the other, so neither is touched.
      def ambiguous_names(grouped, rows)
        here = grouped.select { |_, fields| fields.size > 1 }.keys
        file = rows.map { |row| row['field_name'].to_s }.tally.select { |_, count| count > 1 }.keys
        (here + file).uniq
      end

      def ambiguity(class_name, name)
        "! #{class_name}##{name}: more than one field carries this name -- held back, " \
          'field_name is the only key that travels'
      end

      def upsert(template, class_name, row, existing, dry:)
        name = row['field_name'].to_s
        return ["! #{class_name}: a field with a blank field_name -- skipped"] if name.empty?

        attrs, refusals = attributes(row)
        log = refusals.map { |reason| "! #{class_name}##{name}: #{reason}" }
        record = existing[name]
        log + if record
                update(record, class_name, name, attrs, dry: dry)
              else
                create(template, class_name, name, attrs, existing, dry: dry)
              end
      end

      # The columns the file actually carries, plus the local id of the group a
      # field is restricted to. Keys the file omits are left alone rather than
      # nilled, so a dump that drops a blank column cannot clear one set here.
      def attributes(row)
        attrs = row.slice(*FormSeed::FIELD_COLUMNS)
        name = row['restricted_to_group']
        return [attrs, []] if name.blank?

        group = Group.find_by(group_name: name)
        return [attrs, ["restricted_to_group #{name} is not a group in this database"]] unless group

        [attrs.merge('restricted_to_group_id' => group.id), []]
      end

      def create(template, class_name, name, attrs, existing, dry:)
        return ["! #{class_name}##{name}: needs field_type and page_number to be created"] unless creatable?(attrs)
        return ["+ field  #{class_name}##{name}"] if dry

        record = Forms::Field.new(attrs.merge('form_template_id' => template.id, 'field_name' => name))
        return [refused(class_name, name, record)] unless save(record)

        existing[name] = record
        ["+ field  #{class_name}##{name}"]
      end

      def creatable?(attrs)
        attrs['field_type'].present? && !attrs['page_number'].nil?
      end

      def update(record, class_name, name, attrs, dry:)
        changed = attrs.reject { |column, value| record.public_send(column) == value }
        return [] if changed.empty?

        line = "~ field  #{class_name}##{name}: #{changed.keys.join(', ')}"
        return [line] if dry

        record.assign_attributes(changed)
        save(record) ? [line] : [refused(class_name, name, record)]
      end

      def relink(class_name, row, existing, dry:)
        record = existing[row['field_name'].to_s]
        return [] unless record

        FormSeed::LINKS.filter_map { |key, column| link(record, class_name, row, key, column, existing, dry: dry) }
      end

      def link(record, class_name, row, key, column, existing, dry:)
        target_name = row[key].to_s
        return clear_link(record, class_name, key, column, dry: dry) if target_name.empty?

        target = existing[target_name]
        name = record.field_name
        return "! #{class_name}##{name}: #{key} names #{target_name}, which this form has no field for" unless target
        return nil if record.public_send(column) == target.id

        write_link(record, "~ link   #{class_name}##{name}: #{key} -> #{target_name}", column, target.id, class_name, dry: dry)
      end

      def clear_link(record, class_name, key, column, dry:)
        return nil if record.public_send(column).nil?

        write_link(record, "~ link   #{class_name}##{record.field_name}: #{key} cleared", column, nil, class_name, dry: dry)
      end

      def write_link(record, line, column, value, class_name, dry:)
        return line if dry

        record.assign_attributes(column => value)
        save(record) ? line : refused(class_name, record.field_name, record)
      end

      # Validation failures are a refusal rather than an exception: a custom
      # lookup can name a table this database does not have, and one such field
      # must not take the rest of the deploy with it.
      def save(record)
        record.save
      rescue ActiveRecord::ActiveRecordError => e
        record.errors.add(:base, e.message)
        false
      end

      def refused(class_name, name, record)
        "! #{class_name}##{name}: #{record.errors.full_messages.join('; ')}"
      end

      # Only reachable with PRUNE=1. Nothing points at form_fields by foreign
      # key, so a removed field leaves at worst a dangling conditional pointer
      # on a field the file no longer describes.
      def prune_extras(class_name, rows, existing, dry:)
        wanted = rows.map { |row| row['field_name'].to_s }
        (existing.keys - wanted).sort.map do |name|
          existing[name].destroy! unless dry
          "- field  #{class_name}##{name}"
        end
      end
    end
  end
end
