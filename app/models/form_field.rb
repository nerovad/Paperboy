class FormField < ApplicationRecord
  # Serialize options as JSON (Rails 7.1+ syntax)
  attribute :options, :json
  attribute :conditional_values, :json
  attribute :conditional_answer_mappings, :json

  belongs_to :form_template

  FIELD_TYPES = %w[text text_box dropdown choices_dropdown date phone email number currency yes_no time media_attachment].freeze
  RESTRICTION_TYPES = %w[none employee group].freeze
  READ_ONLY_TYPES = %w[none always initial].freeze

  # Whitelisted database tables and columns available as dropdown data sources
  DATA_SOURCES = {
    'agencies' => {
      model: 'Agency',
      label: 'Agencies',
      order: ':long_name',
      columns: {
        'long_name'  => 'Name',
        'short_name' => 'Short Name',
        'agency_id'  => 'Agency ID'
      }
    },
    'divisions' => {
      model: 'Division',
      label: 'Divisions',
      order: ':long_name',
      columns: {
        'long_name'   => 'Name',
        'short_name'  => 'Short Name',
        'division_id' => 'Division ID'
      }
    },
    'departments' => {
      model: 'Department',
      label: 'Departments',
      order: ':long_name',
      columns: {
        'long_name'      => 'Name',
        'short_name'     => 'Short Name',
        'department_id'  => 'Department ID'
      }
    },
    'units' => {
      model: 'Unit',
      label: 'Units',
      order: ':long_name',
      columns: {
        'long_name' => 'Name',
        'unit_id'   => 'Unit ID'
      }
    },
    'employees' => {
      model: 'Employee',
      label: 'Employees',
      order: ':Last_Name',
      columns: {
        'full_name'  => 'Full Name (Last, First)',
        'first_name' => 'First Name',
        'last_name'  => 'Last Name',
        'email'      => 'Email'
      }
    }
  }.freeze

  validates :field_name, presence: true
  validates :field_type, inclusion: { in: FIELD_TYPES }
  validates :restricted_to_type, inclusion: { in: RESTRICTION_TYPES }, allow_nil: true
  validates :read_only, inclusion: { in: READ_ONLY_TYPES }, allow_nil: true
  validates :restricted_to_employee_id, presence: true, if: :restricted_to_employee?
  validates :restricted_to_group_id, presence: true, if: :restricted_to_group?
  validates :page_number, numericality: {
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: ->(field) { field.form_template&.page_count || 30 }
  }

  before_validation :generate_field_name, on: :create
  before_validation :set_default_restriction_type
  before_save :set_default_options

  scope :for_page, ->(page_num) { where(page_number: page_num).order(:position) }
  scope :ordered, -> { order(:page_number, :position) }
  scope :unrestricted, -> { where(restricted_to_type: ['none', nil]) }
  scope :restricted, -> { where.not(restricted_to_type: ['none', nil]) }
  scope :dropdowns, -> { where(field_type: ['dropdown', 'choices_dropdown']) }
  scope :conditional, -> { where.not(conditional_field_id: nil) }
  scope :unconditional, -> { where(conditional_field_id: nil) }
  scope :custom_view, -> { where(has_custom_view: true) }
  
  def text_field?
    field_type == 'text'
  end
  
  def text_box?
    field_type == 'text_box'
  end
  
  def dropdown?
    field_type == 'dropdown'
  end

  def choices_dropdown?
    field_type == 'choices_dropdown'
  end

  def date?
    field_type == 'date'
  end

  def phone?
    field_type == 'phone'
  end

  def email?
    field_type == 'email'
  end

  def number?
    field_type == 'number'
  end

  def currency?
    field_type == 'currency'
  end

  def yes_no?
    field_type == 'yes_no'
  end

  def time?
    field_type == 'time'
  end

  def media_attachment?
    field_type == 'media_attachment'
  end
  
  def rows
    options&.dig('rows') || 5
  end
  
  def dropdown_values
    options&.dig('values') || []
  end

  # Data source helpers
  def data_source?
    options&.dig('data_source').present?
  end

  def data_source_table
    options&.dig('data_source')
  end

  def data_source_column
    options&.dig('data_source_column')
  end

  def data_source_agency
    options&.dig('data_source_agency')
  end

  # Returns Ruby code string for use in generated ERB views
  def data_source_query_code
    return nil unless data_source?

    config = DATA_SOURCES[data_source_table]
    return nil unless config

    col = data_source_column
    model = config[:model]
    order = config[:order]

    agency_filter = ""
    if data_source_table == 'employees' && data_source_agency.present?
      agency_filter = ".where(Agency: '#{data_source_agency}')"
    end

    if data_source_table == 'employees' && col == 'full_name'
      "#{model}#{agency_filter}.order(#{order}).map { |e| \"\#{e.last_name}, \#{e.first_name}\" }"
    else
      "#{model}#{agency_filter}.order(#{order}).pluck(:#{col}).uniq"
    end
  end

  # Restriction type checks
  def restricted?
    restricted_to_type.present? && restricted_to_type != 'none'
  end

  def unrestricted?
    !restricted?
  end

  def restricted_to_employee?
    restricted_to_type == 'employee'
  end

  def restricted_to_group?
    restricted_to_type == 'group'
  end

  # Read-only checks
  def read_only?
    read_only.present? && read_only != 'none'
  end

  def read_only_always?
    read_only == 'always'
  end

  def read_only_initial?
    read_only == 'initial'
  end

  # Check if a user can fill out this field
  def editable_by?(employee_id, user_groups = [])
    return true if unrestricted?

    if restricted_to_employee?
      restricted_to_employee_id.to_s == employee_id.to_s
    elsif restricted_to_group?
      user_groups.any? { |g| g.to_s == restricted_to_group_id.to_s }
    else
      true
    end
  end

  # Check if field should be required for this user
  def required_for?(employee_id, user_groups = [])
    return required if unrestricted?
    required && editable_by?(employee_id, user_groups)
  end

  # Get the name of the restricted employee
  def restricted_employee_name
    return nil unless restricted_to_employee?
    employee = Employee.find_by(employee_id: restricted_to_employee_id)
    employee ? "#{employee.first_name} #{employee.last_name}" : "Employee ##{restricted_to_employee_id}"
  rescue
    "Employee ##{restricted_to_employee_id}"
  end

  # Get the name of the restricted group
  def restricted_group_name
    return nil unless restricted_to_group?
    Group.find_by(GroupID: restricted_to_group_id)&.group_name || "Group ##{restricted_to_group_id}"
  rescue
    "Group ##{restricted_to_group_id}"
  end

  # Human-readable restriction description
  def restriction_label
    case restricted_to_type
    when 'employee'
      "To be filled by: #{restricted_employee_name}"
    when 'group'
      "To be filled by: #{restricted_group_name}"
    else
      nil
    end
  end

  # Conditional field logic
  def conditional?
    conditional_field_id.present? && conditional_values.present? && Array(conditional_values).any?
  end

  def unconditional?
    !conditional?
  end

  # Get the field this depends on
  def conditional_field
    return nil unless conditional_field_id.present?
    form_template.form_fields.find_by(id: conditional_field_id)
  end

  # Get the label of the conditional field for display
  def conditional_field_label
    conditional_field&.label
  end

  # Check if this field should be visible given a dropdown value
  def visible_for_value?(value)
    return true if unconditional?
    conditional_values.include?(value.to_s)
  end

  # Human-readable conditional description
  def conditional_label
    return nil unless conditional?
    field = conditional_field
    return nil unless field
    values = conditional_values.join(', ')
    "Shows when \"#{field.label}\" is: #{values}"
  end

  # Conditional answer logic - auto-select a value based on another dropdown's selection
  def conditional_answer?
    conditional_answer_field_id.present? && conditional_answer_mappings.present? && conditional_answer_mappings.any?
  end

  def conditional_answer_field
    return nil unless conditional_answer_field_id.present?
    form_template.form_fields.find_by(id: conditional_answer_field_id)
  end

  def conditional_answer_field_label
    conditional_answer_field&.label
  end

  def answer_for_value(value)
    return nil unless conditional_answer?
    conditional_answer_mappings[value.to_s]
  end

  def conditional_answer_label
    return nil unless conditional_answer?
    field = conditional_answer_field
    return nil unless field
    mappings = conditional_answer_mappings.map { |k, v| "#{k} → #{v}" }.join(', ')
    "Auto-answers based on \"#{field.label}\": #{mappings}"
  end

  private

  def set_default_restriction_type
    self.restricted_to_type ||= 'none'
    self.read_only ||= 'none'
  end

  def generate_field_name
    return if label.blank?
    return if field_name.present?

    self.field_name = label.downcase.gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, '_')
  end
  
  def set_default_options
    self.options ||= {}
    
    case field_type
    when 'text_box'
      self.options['rows'] ||= 5
    when 'dropdown', 'choices_dropdown'
      self.options['values'] ||= []
    end
  end
end
