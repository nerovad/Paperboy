# frozen_string_literal: true

# app/services/forms/duplicator/definition_copier.rb

module Forms
  class Duplicator
    # Copies the database half of a form: the template row and its fields, and
    # -- when ticked -- its workflow, ACL grants, visibility grants and
    # subscriptions. Everything is re-keyed to the copy: ids that point between
    # rows (a field's condition, a routing step's status) are remapped, and ACL
    # keys that embed the form's id or class name are rewritten.
    #
    # Deliberately not copied, whatever is ticked:
    # * reference_prefix -- unique per form; the new template derives its own.
    # * the Metabase dashboard link -- that dashboard reads the original table.
    # * submissions and anything hanging off them (status history, edit trail,
    #   attachments), and per-user state (saved searches, scheduled reports,
    #   column layouts). A copy is a new, empty form.
    class DefinitionCopier
      TEMPLATE_SKIP = %w[id name class_name reference_prefix created_at updated_at created_by archived
                         has_dashboard metabase_dashboard_id].freeze
      ROW_SKIP = %w[id form_template_id created_at updated_at].freeze

      def initialize(source:, name:, components:, actor_id:, renamer:)
        @source = source
        @name = name
        @components = components
        @actor_id = actor_id
        @renamer = renamer
      end

      # Returns the new template. Raises (ActiveRecord::RecordInvalid) on any
      # invalid row; the caller runs this inside a transaction.
      def call
        template = create_template
        copy_fields(template)
        copy_workflow(template) if copied?('workflow')
        AclCopier.new(@source).copy_to(template) if copied?('access')
        copy_visibility(template) if copied?('visibility')
        template
      end

      private

      def copied?(key) = @components.include?(key)

      def create_template
        attrs = @source.attributes.except(*TEMPLATE_SKIP)
        attrs.merge!(workflow_free_attributes) unless copied?('workflow')

        template = Forms::Template.new(attrs.merge('name' => @name, 'created_by' => @actor_id,
                                                   'archived' => !copied?('sidebar')))
        # Approval forms with routing steps skip the legacy approver check only
        # once they have steps; the steps are copied right after this save.
        template.pending_routing_steps = @source.routing_steps.to_a if copied?('workflow') && @source.routing_steps.any?
        template.save!
        template
      end

      # Without its workflow a copy is a plain data-collection form until
      # someone configures routing in the builder.
      def workflow_free_attributes
        { 'submission_type' => 'database', 'approval_routing_to' => nil, 'approval_employee_id' => nil,
          'inbox_buttons' => [] }
      end

      def copy_fields(template)
        source_fields = @source.form_fields.order(:page_number, :position, :id).to_a
        new_ids = source_fields.to_h do |field|
          copy = template.form_fields.create!(field.attributes.except(*ROW_SKIP, 'conditional_field_id',
                                                                      'conditional_answer_field_id'))
          [field.id, copy.id]
        end

        source_fields.each do |field|
          links = {
            conditional_field_id: new_ids[field.conditional_field_id],
            conditional_answer_field_id: new_ids[field.conditional_answer_field_id]
          }.compact
          Forms::Field.where(id: new_ids[field.id]).update_all(links) if links.any?
        end
      end

      def copy_workflow(template)
        status_ids = @source.statuses.to_a.to_h do |status|
          [status.id, template.statuses.create!(status.attributes.except(*ROW_SKIP)).id]
        end
        @source.routing_steps.each do |step|
          attrs = step.attributes.except(*ROW_SKIP)
          attrs['form_template_status_id'] = status_ids[step.form_template_status_id]
          template.routing_steps.create!(attrs)
        end
        @source.email_steps.each { |step| template.email_steps.create!(renamed_email(step)) }
        @source.copy_recipients.each { |row| template.copy_recipients.create!(row.attributes.except(*ROW_SKIP)) }
      end

      # An email that names the form ("Your Safety Reporting was approved")
      # names the copy instead.
      def renamed_email(step)
        attrs = step.attributes.except(*ROW_SKIP)
        %w[subject body].each { |column| attrs[column] = @renamer.text(attrs[column]) if attrs[column].present? }
        attrs
      end

      def copy_visibility(template)
        [Forms::VisibilityGrant, Forms::Subscription].each do |model|
          model.where(form_type: @source.class_name).find_each do |row|
            model.create!(row.attributes.except('id', 'created_at', 'updated_at')
                             .merge('form_type' => template.class_name))
          end
        end
      end
    end
  end
end
