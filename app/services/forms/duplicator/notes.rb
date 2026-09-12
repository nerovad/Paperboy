# frozen_string_literal: true

# app/services/forms/duplicator/notes.rb

module Forms
  class Duplicator
    # What an admin should know about a copy that has just been made: the
    # places it still leans on the original or on the rest of the app, which
    # renaming cannot fix on its own. Read after the copy is written, since
    # the renamer only learns what it left alone while it works.
    class Notes
      def initialize(duplicator)
        @dup = duplicator
        @source = duplicator.source
      end

      def to_a
        [*untouched, *associations, hand_written_controller, *authorization_steps,
         data_runner, dashboard, archived].compact
      end

      private

      def copied?(key) = @dup.copies?(key)

      def untouched
        @dup.renamer.untouched.sort.map do |constant|
          "The copy still uses #{constant}, which belongs to another part of the app rather than to the form."
        end
      end

      # has_one/has_many links into tables that were not copied. The other
      # side still keys on the original (osha_reports.safety_report_id), so
      # the copy's association has no column to follow.
      def associations
        model = @source.class_name.safe_constantize
        return [] unless copied?('model') && model.respond_to?(:reflect_on_all_associations)

        model.reflect_on_all_associations.filter_map do |assoc|
          next unless %i[has_one has_many].include?(assoc.macro)
          # Polymorphic links (status history, edit trail) key on the class
          # name as well as the id, so they follow the copy on their own.
          next if assoc.options[:through] || assoc.options[:as]

          target = assoc.klass
          next if @dup.source_tables.include?(target.table_name) || assoc.name.to_s.end_with?('_attachments', '_blobs')

          "#{target.name} links to #{@source.class_name} through #{target.table_name}.#{assoc.foreign_key}, " \
            "so anything in the copy that calls #{assoc.name} will fail until that link is extended or removed."
        rescue NameError
          next
        end
      end

      def hand_written_controller
        path = @dup.code.files_for('controller').first
        return unless copied?('controller') && path
        return if Rails.root.join(path).read.include?('# Generated controller for')

        "#{path} is hand-written; its custom logic was copied as-is and is worth a read."
      end

      def authorization_steps
        return [] unless copied?('workflow')

        @source.routing_steps.select(&:routes_to_authorization?).map do |step|
          "Routing step #{step.step_number} still routes to #{step.authorization_service_type_label}, " \
            'the same approvers as the original.'
        end
      end

      def data_runner
        return unless copied?('data_runner') && @dup.code.files_for('data_runner').any?

        'The Data Runner DSL was copied with its daily schedule paused, since it truncates the table it loads.'
      end

      def dashboard
        return unless @source.dashboard?

        'The Metabase dashboard link was not copied: that dashboard reads the original table.'
      end

      def archived
        return if copied?('sidebar')

        'The copy was created archived; unarchive it to list it in the sidebar.'
      end
    end
  end
end
