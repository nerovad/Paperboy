# frozen_string_literal: true

module HsaAdoptionCards
  # dbo.HSA_Adopt_usp_SearchCards: every card matching the criteria plus the
  # rest of each card's triangulated case. The keys are the ones the page's
  # JSON uses; the values are the procedure's parameters.
  class CardSearch
    PROCEDURE = 'dbo.HSA_Adopt_usp_SearchCards'

    MAPPING = {
      'lastName' => '@LastName',   'firstName' => '@FirstName', 'caseNumber' => '@CaseNumber',
      'venOrA' => '@VEN_or_A',     'dob' => '@DOB',             'dobYear' => '@DOBYear',
      'anyText' => '@AnyText',     'fuzzy' => '@Fuzzy',         'dobFuzzy' => '@DOBFuzzy',
      'nameRole' => '@NameRole',   'names' => '@Names',
      'anywhere' => '@Anywhere',   'closeDate' => '@CloseDate', 'finalDate' => '@FinalDate',
      'anyDate' => '@AnyDate',     'cardType' => '@CardType'
    }.freeze

    # A search with none of these is a request for every card, which the
    # procedure would honour. The page refuses it too; this is the backstop.
    CRITERIA = %w[lastName firstName names anywhere caseNumber venOrA
                  dob dobYear closeDate finalDate anyDate anyText].freeze

    def self.call(params, app_user:)
      new.call(params, app_user: app_user)
    end

    def call(params, app_user:)
      raise Error, 'Enter something to search for.' unless CRITERIA.any? { |key| params[key].to_s.strip.present? }

      Procedure.new(PROCEDURE, MAPPING).call(params, app_user: app_user)
    end
  end
end
