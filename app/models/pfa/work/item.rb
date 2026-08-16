# frozen_string_literal: true

module Pfa
  module Work
    # Application-neutral representation consumed by shared work surfaces.
    class Item
      ATTRIBUTES = %i[
        key application source_type source_id reference title owner_employee_id
        assignee_employee_id status status_category created_at updated_at path
        actions metadata source
      ].freeze

      attr_reader(*ATTRIBUTES)

      def initialize(**attributes)
        unknown = attributes.keys - ATTRIBUTES
        raise ArgumentError, "unknown attributes: #{unknown.join(', ')}" if unknown.any?

        ATTRIBUTES.each { |name| instance_variable_set("@#{name}", attributes[name]) }
        @application = application&.to_sym
        @source_id = source_id.to_s
        @actions = Array(actions).freeze
        @metadata = (metadata || {}).with_indifferent_access.freeze
        validate!
        freeze
      end

      def assigned_to?(employee_id)
        assignee_employee_id.present? && assignee_employee_id.to_s == employee_id.to_s
      end

      def terminal?
        %i[approved denied cancelled completed].include?(status_category&.to_sym)
      end

      private

      def validate!
        %i[key application source_type source_id title].each do |name|
          raise ArgumentError, "#{name} is required" if public_send(name).blank?
        end
      end
    end
  end
end
