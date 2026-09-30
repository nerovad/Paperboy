# frozen_string_literal: true

# Employee lookups shared by the DAM access rule screens. Employees live on
# GSABSS, so both are best-effort: a lookup that fails leaves ids showing
# rather than taking the ACL screen down with it.
module DamAccessRulesAdmin
  extend ActiveSupport::Concern

  private

  def employee_names(ids)
    ids = ids.compact_blank.uniq
    return {} if ids.empty?

    Employee.where(id: ids).pluck(:id, :first_name, :last_name)
            .to_h { |id, first, last| [id.to_s, Employee.format_full_name(first, last)] }
  rescue StandardError
    {}
  end

  # The same search the group Members page runs.
  def employee_search(term)
    return [] if term.to_s.strip.blank?

    Employee.search_ranked(term).limit(20).to_a
  rescue StandardError
    []
  end
end
