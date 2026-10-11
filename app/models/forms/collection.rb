# frozen_string_literal: true

module Forms
  # A named group of blank forms in the Form Library, made by someone for an
  # audience — "Human Resources", "New hire packet". It records who made it
  # and when.
  #
  # A collection is shared furniture, not a grant. It names forms; whether a
  # viewer may open any one of them is still the form ACL's decision, so two
  # people looking at the same collection can see different forms in it (see
  # FormLibrary).
  class Collection < ApplicationRecord
    self.table_name = 'form_collections'

    has_many :collection_forms, class_name: 'Forms::CollectionForm', foreign_key: :form_collection_id,
                                dependent: :destroy, autosave: true, inverse_of: :collection

    validates :name, presence: true

    scope :alphabetical, -> { order(:name) }

    def to_s = name

    # The forms it names, by the key the form ACL knows each one by.
    def form_keys
      collection_forms.map(&:form_key)
    end

    # What the library's search box matches a collection on.
    def haystack
      [name, description].join(' ').downcase
    end

    # Sets the membership an editor chose, touching only the forms that editor
    # can see. A form the editor's own ACL hides was never on their screen, so
    # leaving it unticked there is not a decision to remove it.
    def replace_forms(chosen_keys, among:, added_by_id:)
      chosen = Array(chosen_keys).map(&:to_s) & among
      collection_forms.select { |row| among.include?(row.form_key) && chosen.exclude?(row.form_key) }
                      .each(&:mark_for_destruction)
      (chosen - form_keys).each { |key| collection_forms.build(form_key: key, added_by_id: added_by_id) }
    end
  end
end
