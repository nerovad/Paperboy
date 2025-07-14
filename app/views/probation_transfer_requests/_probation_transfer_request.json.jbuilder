json.extract! probation_transfer_request, :id, :employee_id, :name, :email, :phone, :agency, :division, :department, :unit, :work_location, :current_assignment_date, :desired_transfer_destination, :status, :created_at, :updated_at
json.url probation_transfer_request_url(probation_transfer_request, format: :json)
