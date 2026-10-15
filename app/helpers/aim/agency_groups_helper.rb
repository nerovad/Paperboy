# frozen_string_literal: true

module Aim
  # Agency groups on screen (#131).
  module AgencyGroupsHelper
    # "SHF · Sheriff", or "SHF · Sheriff (also processes Patrol)".
    def aim_agency_group_label(group)
      covered = aim_agency_groups.covers(group).map(&:name)
      covered.any? ? "#{group.name} (also processes #{covered.to_sentence})" : group.name
    end

    # A Help page screenshot (#131), when app/assets/images/aim/help/<name>.png
    # is there; nothing otherwise.
    def aim_help_shot(name, caption)
      return unless Rails.root.join("app/assets/images/aim/help/#{name}.png").exist?

      tag.figure(class: 'aim-help__shot') do
        image_tag("aim/help/#{name}.png", alt: caption, loading: 'lazy') + tag.figcaption(caption)
      end
    end

    # A person's roles in their agency groups: [[group, ['Fiscal', ...]], ...].
    def aim_agency_group_roles_of(employee_id)
      Aim::AgencyGroupRole.includes(:agency_group).where(employee_id: employee_id).group_by(&:agency_group)
                          .sort_by { |group, _| group.name }.map { |group, roles| [group, roles.map(&:label).sort] }
    rescue ActiveRecord::ActiveRecordError
      []
    end
  end
end
