# frozen_string_literal: true

module Paperboy
  module AclSeed
    # Form-backed permission keys are the one part of an ACL grant that means
    # nothing outside the database that issued it:
    #
    #   type 'form',        key '40'      → form_templates.id
    #   type 'record_view', key 'form-33' → form_templates.id, prefixed
    #
    # form_templates.id is an identity column and the three Paperboy databases
    # allocate it independently — Dev is already at 51 while Prod stops at 39 —
    # so the same number names a different form in each. Dumps therefore record
    # the template's class_name, which is stable everywhere because it names a
    # class checked into the repo, and sync rewrites the key to whatever id that
    # class happens to have locally. A form that does not exist in the target
    # database is refused with a reason rather than granted against whatever
    # form now holds that id.
    #
    # Keys that are not form-backed pass through untouched: dropdown,
    # application and feature keys are already stable strings, as are the
    # AclController::LEGACY_FORMS keys such as 'creative_job_request'.
    module FormKey
      NUMERIC = /\A\d+\z/
      RECORD_KEY = /\Aform-(\d+)\z/

      module_function

      # One lookup of this database's templates, built once per dump or sync so
      # that a few hundred grants do not become a few hundred queries.
      def index(scope = Forms::Template.all)
        templates = scope.to_a
        { by_id: templates.index_by { |template| template.id.to_s },
          by_class: templates.index_by(&:class_name),
          by_name: templates.index_by(&:name) }
      end

      # ['', '40'] or ['form-', '33'] when the key points at a form_templates
      # row, else nil.
      def parts(type, key)
        return ['', key.to_s] if type.to_s == 'form' && key.to_s.match?(NUMERIC)

        match = type.to_s.start_with?('record_') ? RECORD_KEY.match(key.to_s) : nil
        match && ['form-', match[1]]
      end

      # The portable identity to dump alongside a form-backed key. Empty for
      # every other kind of key, and for an id with no template behind it — sync
      # refuses those loudly rather than guessing.
      def identity(type, key, index)
        parts = parts(type, key)
        return {} unless parts

        template = index[:by_id][parts.last]
        return {} unless template

        { 'class' => template.class_name, 'label' => template.name }
      end

      # [key, nil] with the key rewritten for this database, or [nil, reason]
      # when the grant cannot be honoured here.
      def resolve(row, index)
        type = row['type'].to_s
        key = row['key'].to_s
        prefix, = parts(type, key)
        return [key, nil] unless prefix

        template = lookup(row, index)
        template ? ["#{prefix}#{template.id}", nil] : [nil, refusal(type, key, row)]
      end

      def lookup(row, index)
        by_class = index[:by_class][row['class']] if row['class'].present?
        by_class || (index[:by_name][row['label']] if row['label'].present?)
      end

      def refusal(type, key, row)
        form = row['class'].presence || row['label'].presence
        return "#{type}/#{key} names no form in db/acl.yml — re-run acl:dump where that form exists" unless form

        "#{type}/#{key} — #{form} does not exist in this database; create the form here first"
      end

      # What makes two rows for the same grant equal across databases: the form
      # it names, not the id it happened to have where it was dumped.
      def identity_key(row)
        row['class'].presence || row['label'].presence || row['key'].to_s
      end
    end
  end
end
