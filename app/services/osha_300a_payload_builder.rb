class Osha300aPayloadBuilder
  def initialize(establishment:, entry:, totals:)
    @establishment = establishment
    @entry         = entry
    @totals        = totals
  end

  def to_h
    {
      # Establishment identification
      establishment_name: @establishment.name,
      ein_number: @establishment.ein,
      company_name: @establishment.company_name,

      # Address
      street_address: @establishment.street_address,
      city: @establishment.city,
      state: @establishment.state,
      zip: @establishment.zip,

      # Industry
      naics_code: @establishment.naics_code,
      industry_description: @establishment.industry_description,

      # Establishment classification
      size: @establishment.size,
      establishment_type: @establishment.establishment_type,

      # Filing year + workforce
      year_filing_for: @entry.year,
      annual_average_employees: @entry.annual_average_employees,
      total_hours_worked: @entry.total_hours_worked,

      # Computed totals
      no_injuries_illnesses: @totals[:no_injuries_illnesses],
      total_deaths: @totals[:total_deaths],
      total_dafw_cases: @totals[:total_dafw_cases],
      total_djtr_cases: @totals[:total_djtr_cases],
      total_other_cases: @totals[:total_other_cases],
      total_dafw_days: @totals[:total_dafw_days],
      total_djtr_days: @totals[:total_djtr_days],
      total_injuries: @totals[:total_injuries],
      total_skin_disorders: @totals[:total_skin_disorders],
      total_respiratory_conditions: @totals[:total_respiratory_conditions],
      total_poisonings: @totals[:total_poisonings],
      total_hearing_loss: @totals[:total_hearing_loss],
      total_other_illnesses: @totals[:total_other_illnesses],

      # Amendment metadata
      change_reason: @entry.change_reason
    }
  end

  def to_json(*_args)
    JSON.pretty_generate(to_h)
  end
end
