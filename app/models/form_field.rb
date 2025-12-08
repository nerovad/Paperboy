class FormField < ApplicationRecord
  belongs_to :form_template
  
  FIELD_TYPES = %w[text text_box dropdown].freeze
  
  validates :field_name, presence: true
  validates :field_type, inclusion: { in: FIELD_TYPES }
  validates :page_number, numericality: { 
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: ->(field) { field.form_template&.page_count || 30 }
  }
  
  before_validation :generate_field_name, on: :create
  before_save :set_default_options
  
  scope :for_page, ->(page_num) { where(page_number: page_num).order(:position) }
  scope :ordered, -> { order(:page_number, :position) }
  
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
  
  private
  
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
