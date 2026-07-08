class FormRequestForm < ApplicationRecord
  include TrackableStatus

  has_many_attached :attach_existing_pdf_form

  # Scopes
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true
  validate :acceptable_attach_existing_pdf_form_files
  validate :column_names_must_be_valid_identifiers

  # Rejects any column name starting with a digit — these break ERB symbol syntax.
  # e.g. :30_day_spending_limit is invalid; use :spending_limit_30_day instead.
  def column_names_must_be_valid_identifiers
    self.class.column_names.each do |col|
      unless col.match?(/\A[a-zA-Z_]/)
        errors.add(:base, "Column '#{col}' is invalid: names must start with a letter or underscore, not a number.")
      end
    end
  end

  # For inbox queue filtering - returns the form type name
  def form_type
    self.class.name.demodulize.titleize
  end

  # For inbox reassignment - returns the current approver's ID
  def current_assignee_id
    approver_id
  end

  # Get the form template for this model (for button configuration)
  def form_template
    @form_template ||= FormTemplate.find_by(class_name: self.class.name)
  end

def acceptable_attach_existing_pdf_form_files
  return unless attach_existing_pdf_form.attached?

  if attach_existing_pdf_form.count > 10
    errors.add(:attach_existing_pdf_form, "can have a maximum of 10 files")
  end

  attach_existing_pdf_form.each do |file|
    unless file.content_type.in?(%w[image/jpeg image/png image/gif image/webp image/heic image/heif application/pdf])
      errors.add(:attach_existing_pdf_form, "must be a JPEG, PNG, GIF, WebP, HEIC, or PDF")
    end

    if file.byte_size > 10.megabytes
      errors.add(:attach_existing_pdf_form, "file size must be less than 10MB")
    end
  end
end

end
