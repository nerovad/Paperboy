# frozen_string_literal: true

module Forms
  # One form's place in a Form Library collection. `form_key` is the key the
  # form ACL uses: a template's id as a string, or a legacy form's permission
  # key (see FormCatalog#key_for).
  class CollectionForm < ApplicationRecord
    self.table_name = 'form_collection_forms'

    belongs_to :collection, class_name: 'Forms::Collection', foreign_key: :form_collection_id,
                            inverse_of: :collection_forms

    validates :form_key, presence: true
  end
end
