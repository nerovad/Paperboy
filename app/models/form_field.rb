class FormField < ApplicationRecord
  # Serialize options as JSON (Rails 7.1+ syntax)
  attribute :options, :json

  belongs_to :form_template

  FIELD_TYPES = %w[text text_box dropdown].freeze
  RESTRICTION_TYPES = %w[none employee group].freeze

  validates :field_name, presence: true
  validates :field_type, inclusion: { in: FIELD_TYPES }
  validates :restricted_to_type, inclusion: { in: RESTRICTION_TYPES }, allow_nil: true
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
  
  def text_field?
    field_type == 'text'
  end
  
  def text_box?
    field_type == 'text_box'
  end
  
  def dropdown?
    field_type == 'dropdown'
  end
  
  def rows
    options&.dig('rows') || 5
  end
  
  def dropdown_values
    options&.dig('values') || []
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
    employee = Employee.find_by(EmployeeID: restricted_to_employee_id)
    employee ? "#{employee.First_Name} #{employee.Last_Name}" : "Employee ##{restricted_to_employee_id}"
  rescue
    "Employee ##{restricted_to_employee_id}"
  end

  # Get the name of the restricted group
  def restricted_group_name
    return nil unless restricted_to_group?
    result = ActiveRecord::Base.connection.execute(
      "SELECT Group_Name FROM GSABSS.dbo.Groups WHERE GroupID = #{restricted_to_group_id}"
    ).first
    result ? result['Group_Name'] : "Group ##{restricted_to_group_id}"
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

  private

  def set_default_restriction_type
    self.restricted_to_type ||= 'none'
  end

  def generate_field_name
    return if label.blank?
    
    self.field_name = label.downcase.gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, '_')
  end
  
  def set_default_options
    self.options ||= {}
    
    case field_type
    when 'text_box'
      self.options['rows'] ||= 5
    when 'dropdown'
      self.options['values'] ||= []
    end
  end
end
