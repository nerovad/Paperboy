class FormTemplate < ApplicationRecord
  attribute :page_headers, :json

  has_many :form_fields, dependent: :destroy

  validates :name, presence: true
  validates :class_name, presence: true, uniqueness: true
  validates :access_level, inclusion: { in: %w[public restricted] }
  validates :page_count, numericality: { greater_than_or_equal_to: 2, less_than_or_equal_to: 30 }
  validates :acl_group_id, presence: true, if: :restricted?
  
  before_validation :generate_class_name, on: :create
  
  def restricted?
    access_level == 'restricted'
  end
  
  def table_name
    class_name.underscore.pluralize
  end
  
  def file_name
    class_name.underscore
  end
  
  def plural_file_name
    file_name.pluralize
  end
  
  def acl_group_name
    return nil unless acl_group_id
    
    result = ActiveRecord::Base.connection.execute(
      "SELECT GroupName FROM GSABSS.dbo.Groups WHERE GroupID = #{acl_group_id}"
    ).first
    
    result ? result['GroupName'] : nil
  end
  
  def page_header(page_num)
    return "Employee Info" if page_num == 1
    return "Agency Info" if page_num == 2
    
    headers = page_headers || []
    headers[page_num - 3]
  end
  
  private
  
  def generate_class_name
    return if name.blank?
    
    self.class_name = name.gsub(/[^a-zA-Z0-9\s]/, '').split.map(&:capitalize).join + 'Form'
  end
end
