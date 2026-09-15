# frozen_string_literal: true

# app/services/forms/duplicator/preview.rb

module Forms
  class Duplicator
    # What the duplicate dialog shows before anything is written: the renames
    # the new name implies, and for each component what it would copy. A
    # component with nothing to copy (a form with no PDF generator, no ACL
    # grants) is reported as unavailable so the dialog can grey it out.
    class Preview
      def initialize(duplicator)
        @dup = duplicator
        @source = duplicator.source
      end

      def to_h
        {
          name: @dup.name,
          class_name: @dup.named? ? @dup.class_name : nil,
          valid: @dup.valid?,
          errors: @dup.errors,
          identity: identity,
          components: Components::KEYS.index_with { |key| component(key) }
        }
      end

      # Keys with nothing to copy for this form.
      def unavailable
        Components::KEYS.select { |key| items(key).empty? }
      end

      private

      def rename(value)
        @dup.named? ? @dup.renamer.text(value) : nil
      end

      def identity
        table = @dup.source_table
        plural = @source.plural_file_name
        [
          ['Form name', @source.name, @dup.named? ? @dup.name : nil],
          ['Class', @source.class_name, @dup.named? ? @dup.class_name : nil],
          ['Table', table, rename(table)],
          ['Controller', "Forms::#{@source.class_name.pluralize}Controller",
           rename("Forms::#{@source.class_name.pluralize}Controller")],
          ['Views', "app/views/forms/#{plural}/", rename("app/views/forms/#{plural}/")],
          ['New-form path', "/#{plural}/new", rename("/#{plural}/new")]
        ]
      end

      def component(key)
        list = items(key)
        { available: list.any?, items: list }
      end

      def items(key)
        @items ||= {}
        @items[key] ||= compute_items(key)
      end

      def compute_items(key)
        case key
        when 'definition' then definition_items
        when 'workflow' then workflow_items
        when 'access' then access_items
        when 'visibility' then visibility_items
        when 'sidebar' then ["Listed in the sidebar as “#{@dup.named? ? @dup.name : '…'}”"]
        when 'table' then table_items
        when 'controller' then file_items(key) + route_items
        else file_items(key)
        end
      end

      def definition_items
        ["#{counted(@source.page_count, 'page')}, #{counted(@source.form_fields.count, 'field')}",
         'A new reference prefix is derived from the new name']
      end

      def workflow_items
        list = tally([[@source.statuses.count, 'status'], [@source.routing_steps.count, 'routing step'],
                      [@source.email_steps.count, 'workflow email'], [@source.copy_recipients.count, 'copy recipient']])
        buttons = @source.enabled_inbox_buttons
        buttons.any? ? list << "Inbox buttons: #{buttons.join(', ')}" : list
      end

      def access_items
        groups, orgs = AclCopier.new(@source).counts
        tally([[groups, 'group'], [orgs, 'org-scope grant']])
      end

      def visibility_items
        tally([[Forms::VisibilityGrant.where(form_type: @source.class_name).count, 'visibility grant'],
               [Forms::Subscription.where(form_type: @source.class_name).count, 'subscription']])
      end

      def table_items
        @dup.source_tables.map do |table|
          columns = ActiveRecord::Base.connection.columns(table).size
          arrow(table, rename(table), " (#{counted(columns, 'column')}, no rows)")
        end
      end

      def file_items(key)
        scanner.files_for(key).map { |path| arrow(path, rename(path)) }
      end

      # Finds files without renaming anything, so availability never depends
      # on the name typed so far.
      def scanner
        @scanner ||= CodeCopier.new(source: @source, renamer: nil, components: %w[controller])
      end

      def route_items
        block = scanner.routes_block
        return [] unless block

        head = block.lines.first.strip
        [arrow("routes.rb #{head.delete_suffix(' do')}", rename("routes.rb #{head.delete_suffix(' do')}"))]
      end

      def arrow(from, to, suffix = '')
        "#{from} → #{to || '…'}#{suffix}"
      end

      # [[2, 'group'], [0, 'org-scope grant']] => ["2 groups"]: the nonzero
      # counts, worded.
      def tally(pairs)
        pairs.filter_map { |count, word| counted(count, word) if count.positive? }
      end

      def counted(count, word)
        "#{count} #{count == 1 ? word : word.pluralize}"
      end
    end
  end
end
