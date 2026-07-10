class Osha300aTotals
  CASE_TYPE_TO_FIELD = {
    'Injury' => :total_injuries,
    'Skin Disorder' => :total_skin_disorders,
    'Respiratory Condition' => :total_respiratory_conditions,
    'Poisoning' => :total_poisonings,
    'Hearing Loss' => :total_hearing_loss,
    'Other Illness' => :total_other_illnesses
  }.freeze

  CASE_CLASSIFICATION_TO_FIELD = {
    'Death' => :total_deaths,
    'DAFW' => :total_dafw_cases,
    'DJTR' => :total_djtr_cases,
    'Other' => :total_other_cases
  }.freeze

  def self.for(year)
    new(year).compute
  end

  def initialize(year)
    @year = year.to_i
  end

  def compute
    range   = Date.new(@year, 1, 1)..Date.new(@year, 12, 31)
    reports = OshaReport
              .where(status: :approved)
              .where(date_of_injury_or_illness: range)
              .to_a

    safety_ids   = reports.map(&:safety_report_id).compact.uniq
    safety_by_id = SafetyReport.where(id: safety_ids).index_by(&:id)

    totals = empty_totals
    totals[:no_injuries_illnesses] = reports.any? ? 1 : 2

    reports.each do |r|
      classify_case(r, totals)
      classify_type(r, totals)
      totals[:total_dafw_days] += days_away_for(r, safety_by_id)
      totals[:total_djtr_days] += r.restricted_duty_days.to_i
    end

    totals[:case_count] = reports.size
    totals[:reports]    = reports
    totals
  end

  private

  def empty_totals
    {
      no_injuries_illnesses: 2,
      total_deaths: 0,
      total_dafw_cases: 0,
      total_djtr_cases: 0,
      total_other_cases: 0,
      total_dafw_days: 0,
      total_djtr_days: 0,
      total_injuries: 0,
      total_skin_disorders: 0,
      total_respiratory_conditions: 0,
      total_poisonings: 0,
      total_hearing_loss: 0,
      total_other_illnesses: 0
    }
  end

  def classify_case(report, totals)
    field = CASE_CLASSIFICATION_TO_FIELD[report.case_classification]
    totals[field] += 1 if field
  end

  def classify_type(report, totals)
    field = CASE_TYPE_TO_FIELD[report.case_type]
    totals[field] += 1 if field
  end

  def days_away_for(report, safety_by_id)
    safety = safety_by_id[report.safety_report_id]
    return 0 unless safety

    last_worked = safety.date_last_worked
    return 0 if last_worked.blank?

    end_date = safety.date_returned_to_work.presence || Date.current
    days     = (end_date - last_worked).to_i
    [[days, 0].max, 180].min
  end
end
