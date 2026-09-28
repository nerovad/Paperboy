# frozen_string_literal: true

module Aim
  # One load of a lookup file (item b): what it was, who loaded it, and how
  # it went. The rules it loaded point back at it, and the rules it retired
  # remember it too, so Undo puts both back as one.
  class CodingImport < Record
    EFFECTIVE_OPTIONS = %w[bdo today date].freeze

    has_many :rules, class_name: 'Aim::CodingRule', foreign_key: :import_id, inverse_of: :import,
                     dependent: :restrict_with_exception
    has_many :retired_rules, class_name: 'Aim::CodingRule', foreign_key: :retired_by_import_id,
                             inverse_of: :retired_by_import, dependent: :restrict_with_exception

    validates :agency, :file_name, :imported_by, presence: true
    validates :effective_option, inclusion: { in: EFFECTIVE_OPTIONS }

    serialize :report, coder: JSON

    def undone? = undone_at.present?

    # Takes the import back: its rules are retired as never in effect, and the
    # rules it retired come back into effect.
    def undo!(by:)
      raise ArgumentError, 'This import was already undone.' if undone?

      transaction do
        rules.find_each { |rule| rule.retire!(on: rule.effective_from - 1, by: by, kind: 'undone') }
        retired_rules.find_each { |rule| rule.restore!(by: by) }
        update!(undone_at: Time.current, undone_by: by)
      end
    end
  end
end
