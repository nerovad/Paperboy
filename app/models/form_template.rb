class FormTemplate < ApplicationRecord
  attribute :page_headers, :json

  has_many :form_fields, dependent: :destroy

  validates :name, presence: true
  validates :class_name, presence: true, uniqueness: true
  validates :access_level, inclusion: { in: %w[public restricted] }
  validates :page_count, numericality: { greater_than_or_equal_to: 2, less_than_or_equal_to: 30 }
  validates :acl_group_id, presence: true, if: :restricted?
  validates :submission_type, inclusion: { in: %w[database approval] }
  validates :approval_routing_to, presence: true, if: :requires_approval?
  validates :approval_employee_id, presence: true, if: :routes_to_specific_employee?
  validates :powerbi_workspace_id, presence: true, if: :has_dashboard?
  validates :powerbi_report_id, presence: true, if: :has_dashboard?

  validate :page_count_cannot_orphan_fields, on: :update

  before_validation :generate_class_name, on: :create

  scope :with_dashboards, -> { where(has_dashboard: true) }
  
  def restricted?
    access_level == 'restricted'
  end

  def requires_approval?
    submission_type == 'approval'
  end

  def routes_to_specific_employee?
    requires_approval? && approval_routing_to == 'employee'
  end

  def has_dashboard?
    has_dashboard == true
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
      "SELECT Group_Name FROM GSABSS.dbo.Groups WHERE GroupID = #{acl_group_id}"
    ).first
    
    result ? result['Group_Name'] : nil
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

  def page_count_cannot_orphan_fields
    return unless page_count_changed? && page_count_was.present?

    if page_count < page_count_was
      max_field_page = form_fields.maximum(:page_number)
      if max_field_page && max_field_page > page_count
        errors.add(:page_count,
          "cannot be reduced to #{page_count} because fields exist on page #{max_field_page}. " \
          "Please remove or move fields first.")
      end
    end
  end
end
