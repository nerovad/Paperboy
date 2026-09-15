# frozen_string_literal: true

# app/services/forms/duplicator/cleanup.rb

module Forms
  class Duplicator
    # Deletes the rows a failed duplication wrote. The template's own
    # dependents (fields, statuses, routing and email steps, copy recipients)
    # go with it; the ACL, visibility and subscription rows are keyed by the
    # new form's id or class name, which nothing else carries, so they can be
    # found without having been tracked.
    class Cleanup
      def initialize(template)
        @template = template
      end

      def call
        class_name = @template.class_name
        AclCopier.new(@template).remove_all
        Forms::VisibilityGrant.where(form_type: class_name).delete_all
        Forms::Subscription.where(form_type: class_name).delete_all
        Forms::Template.find_by(id: @template.id)&.destroy
      rescue StandardError => e
        # Already unwinding a failure; the original error is the one to show.
        Rails.logger.error("Duplicate cleanup for #{class_name} failed: #{e.class}: #{e.message}")
      end
    end
  end
end
