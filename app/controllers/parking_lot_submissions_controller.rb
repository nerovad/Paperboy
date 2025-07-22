class ParkingLotSubmissionsController < ApplicationController
  def new
    @parking_lot_submission = ParkingLotSubmission.new
    @parking_lot_submission.parking_lot_vehicles.build

    # GSABSS lookups
    @agency_options = Agency.all.map { |a| ["#{a.Agency} #{a.LongName}", a.Agency] }

    @form_logo = "/assets/images/default-logo.svg"

    @form_pages = [
      {
        title: "Employee Info",
        fields: [
          { name: "employee_id", label: "Employee ID", type: "text", required: true },
          { name: "name", label: "Name", type: "text", required: true },
          { name: "phone", label: "Phone", type: "text", required: true },
          { name: "email", label: "Email", type: "text", required: true }
        ]
      },
      {
        title: "Agency Info",
        fields: [
          { name: "agency", label: "Agency", type: "select", required: true, options: Agency.all.pluck(:LongName) },
          { name: "division", label: "Division", type: "select", required: true, options: Division.all.pluck(:LongName) },
          { name: "department", label: "Department", type: "select", required: true, options: Department.all.pluck(:LongName) },
          { name: "unit", label: "Unit", type: "select", required: true, options: Unit.all.map { |u| ["#{u.Unit} #{u.LongName}", u.Unit] } }
        ]
      },
      { title: "Vehicle and Parking Info", fields: [] }
    ]
  end

      def create
      employee = session[:user]
      supervisor_id = fetch_supervisor_id(employee["employee_id"])

      Rails.logger.info "Creating submission for employee #{employee["employee_id"]}, supervisor: #{supervisor_id}"

      @parking_lot_submission = ParkingLotSubmission.new(parking_lot_submission_params)
      @parking_lot_submission.status = 0
      @parking_lot_submission.supervisor_id = supervisor_id

      if @parking_lot_submission.save
        redirect_to parking_lot_submissions_path, notice: "Submitted!"
      else
        render :new
      end
    end

  def pdf
    submission = ParkingLotSubmission.find(params[:id])
    pdf_data = ParkingLotPdfGenerator.generate(submission)

    send_data pdf_data,
              filename: "ParkingLotSubmission_#{submission.id}.pdf",
              type: "application/pdf",
              disposition: "inline" # or "attachment" if you want it to download
  end

   def approve
  @submission = ParkingLotSubmission.find(params[:id])
  @submission.update!(status: :manager_approved)

  NotifySecurityJob.perform_later(@submission.id)

  redirect_to parking_lot_submissions_path, notice: "Request approved and sent to Security."
end

def deny
  @submission = ParkingLotSubmission.find(params[:id])
  @submission.update!(status: :denied)

  # Optional: Notify the user
  redirect_to parking_lot_submissions_path, alert: "Request denied."
end

def index
  employee = session[:user]

  if employee.present? && employee["employee_id"].present?
    Rails.logger.info "Logged in as employee #{employee["employee_id"]}"

    session[:last_seen_inbox_at] = Time.current

    @pending_submissions = ParkingLotSubmission
                              .where(supervisor_id: employee["employee_id"].to_s)
                              .where(status: 0)
                              .order(created_at: :desc)
  else
    Rails.logger.warn "No logged-in employee found"
    @pending_submissions = []
  end
end

 private

    def fetch_supervisor_id(employee_id)
      result = ActiveRecord::Base.connection.exec_query(<<-SQL.squish).first
        SELECT Supervisor_ID
        FROM [GSABSS].[dbo].[Employees]
        WHERE EmployeeID = '#{employee_id}'
      SQL

      result&.fetch("Supervisor_ID", nil)
    end

  def parking_lot_submission_params
    params.require(:parking_lot_submission).permit(
      :name,
      :phone,
      :employee_id,
      :email,
      :agency,
      :division,
      :department,
      :unit,
      :status,
      parking_lot_vehicles_attributes: [
        :id,
        :make,
        :model,
        :color,
        :year,
        :license_plate,
        :parking_lot,
        :other_parking_lot,
        :_destroy
      ]
    )
  end

end
