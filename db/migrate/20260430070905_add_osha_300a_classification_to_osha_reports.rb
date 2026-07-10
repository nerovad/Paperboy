class AddOsha300aClassificationToOshaReports < ActiveRecord::Migration[8.0]
  def up
    add_column :osha_reports, :case_classification, :string
    add_column :osha_reports, :case_type, :string

    # Fix the dropdown typo "DTJR" -> "DJTR" (Days of Job Transfer or Restriction).
    # This matches the OSHA ITA 300A field name `total_djtr_cases`.
    field = FormField.joins(:form_template)
                     .find_by(form_templates: { class_name: 'OshaReport' },
                              field_name: 'case_classification')
    return unless field && field.options.is_a?(Hash) && field.options['values'].is_a?(Array)

    values = field.options['values'].map { |v| v == 'DTJR' ? 'DJTR' : v }
    field.update!(options: field.options.merge('values' => values))
  end

  def down
    field = FormField.joins(:form_template)
                     .find_by(form_templates: { class_name: 'OshaReport' },
                              field_name: 'case_classification')
    if field && field.options.is_a?(Hash) && field.options['values'].is_a?(Array)
      values = field.options['values'].map { |v| v == 'DJTR' ? 'DTJR' : v }
      field.update!(options: field.options.merge('values' => values))
    end

    remove_column :osha_reports, :case_type
    remove_column :osha_reports, :case_classification
  end
end
