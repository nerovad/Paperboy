# frozen_string_literal: true

module HsaAdoptionCards
  # Every card in one case group, for the Browse screen's "linked cards".
  #
  # There is no procedure that takes a group id, but SearchCards returns any
  # direct hit together with the rest of its case. So the page sends the
  # row's own identifiers — case number, VEN or A number, or surname and
  # date of birth — which make the row itself a direct hit, and the result
  # is narrowed to the row's group id. A card with no group has no linked
  # cards, and is refused before any SQL is sent.
  class LinkedCards
    # Keys the page may send, in the order they are tried: the first present
    # one is what the search is keyed on.
    IDENTIFIERS = %w[caseNumber venOrA].freeze

    def self.call(params, app_user:)
      new.call(params, app_user: app_user)
    end

    def call(params, app_user:)
      group_id = params['groupId'].to_i
      raise Error, 'This card is not linked to a case.' unless group_id.positive?

      criteria = search_criteria(params)
      raise Error, 'This card has nothing to search by.' if criteria.empty?

      CardSearch.call(criteria.merge('fuzzy' => 0), app_user: app_user)
                .select { |row| row['GroupID'].to_i == group_id }
    end

    private

    def search_criteria(params)
      key = IDENTIFIERS.find { |k| params[k].to_s.strip.present? }
      return { key => params[key] } if key

      surname = params['lastName'].to_s.strip
      dob = params['dob'].to_s.strip
      return {} if surname.empty?

      dob.empty? ? { 'lastName' => surname } : { 'lastName' => surname, 'dob' => dob }
    end
  end
end
