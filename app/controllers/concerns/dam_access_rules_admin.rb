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
            .to_h { |id, first, last| [id.to_s, "#{first} #{last}".strip] }
  rescue StandardError
    {}
  end

  # The same search the group Members page runs.
  def employee_search(term)
    term = term.to_s.strip
    return [] if term.blank?

    Employee.where('first_name LIKE :q OR last_name LIKE :q OR CAST(id AS VARCHAR) LIKE :q ' \
                   "OR (first_name + ' ' + last_name) LIKE :q",
                   q: "%#{ActiveRecord::Base.sanitize_sql_like(term)}%")
            .order(:last_name, :first_name).limit(20).to_a
  rescue StandardError
    []
  end
end
