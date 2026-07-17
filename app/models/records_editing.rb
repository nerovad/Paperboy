# frozen_string_literal: true

# Which Records-table columns may be edited inline. A column is editable only
# when it maps to a real, stored column on the table's model — which already
# excludes derived cells (status_label, owner_name, masked_card_number are
# methods, not columns) — and is not an identity/timestamp column, an encrypted
# attribute, or a non-scalar display kind. This is the security whitelist the
# inline-edit endpoint validates against, so nothing outside it can be written.
module RecordsEditing
  NON_EDITABLE_NAMES = %w[id created_at updated_at].freeze
  NON_EDITABLE_KINDS = %i[status reference datetime].freeze

  module_function

  def editable?(table, column_name, kind = nil)
    name = column_name.to_s
    model = table.model

    model.column_names.include?(name) &&
      NON_EDITABLE_NAMES.exclude?(name) &&
      (kind.nil? || NON_EDITABLE_KINDS.exclude?(kind.to_sym)) &&
      !encrypted?(model, name)
  end

  def encrypted?(model, name)
    return false unless model.respond_to?(:encrypted_attributes)

    Array(model.encrypted_attributes).map(&:to_s).include?(name)
  end
end
