# frozen_string_literal: true

module Aim
  # AIM's stamp designer data (#221): its fields for Insert a field, and the
  # layout's name. The shared pieces are StampDesignerHelper.
  module StampLayoutsHelper
    # [[group, [[field, label, kind], ...]], ...] for Insert a field.
    def stamp_field_groups
      kinds = stamp_values_data(Aim::StampFields.samples)
      Aim::StampFields::FIELDS.group_by { |_, field| field[:group] }.map do |group, fields|
        [group, fields.map { |name, field| [name, field[:label], kinds.dig(name, :kind)] }]
      end
    end

    def stamp_target_name(group) = group&.name || 'Default (groups without their own)'
  end
end
