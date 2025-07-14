class ProbationTransferRequestsController < ApplicationController
  before_action :set_probation_transfer_request, only: [:show, :edit, :update, :destroy]

  def index
    @probation_transfer_requests = ProbationTransferRequest.all
  end

  def show
    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "transfer_request_#{@probation_transfer_request.id}",
               template: "probation_transfer_requests/pdf",
               locals: { request: @probation_transfer_request },
               formats: [:html]
      end
    end
  end

  def new
  @probation_transfer_request = ProbationTransferRequest.new

  @agency_options = Agency.all.map { |a| ["#{a.Agency} #{a.LongName}", a.Agency] }

  @form_logo = "/assets/images/default-logo.svg"

  @form_pages = [
    {
      title: "Employee Info",
      fields: [
        { name: "employee_id", label: "Employee ID", type: "text", required: true },
        { name: "name", label: "Name", type: "text", required: true },
        { name: "email", label: "Email", type: "text", required: true },
        { name: "phone", label: "Phone", type: "text", required: true }
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
    {
      title: "Transfer Request Details",
      fields: [
        { name: "work_location", label: "Work Location", type: "text", required: true },
        { name: "current_assignment_date", label: "Current Assignment Date", type: "text", required: true },
        { name: "desired_transfer_destination", label: "Desired Transfer Destination", type: "multi-select", options: ["East County", "West County", "Downtown", "Remote", "Other"] }
      ]
    }
  ]
end

  def edit
  end

  def create
    raw_params = probation_transfer_request_params

    @probation_transfer_request = ProbationTransferRequest.new(raw_params)
    @probation_transfer_request.status = 0

    if @probation_transfer_request.save
      TransferMailer.notify(@probation_transfer_request).deliver_later
      redirect_to probation_transfer_requests_path, notice: "Transfer request submitted!"
    else
      render :new
    end
  end

  def update
    if @probation_transfer_request.update(probation_transfer_request_params)
      redirect_to @probation_transfer_request, notice: "Transfer request updated."
    else
      render :edit
    end
  end

  def destroy
    @probation_transfer_request.destroy
    redirect_to probation_transfer_requests_url, notice: "Transfer request deleted."
  end

  private

  def set_probation_transfer_request
    @probation_transfer_request = ProbationTransferRequest.find(params[:id])
  end

  def probation_transfer_request_params
    params.require(:probation_transfer_request).permit(
      :employee_id,
      :name,
      :email,
      :phone,
      :agency,
      :division,
      :department,
      :unit,
      :work_location,
      :current_assignment_date,
      :desired_transfer_destination,
      :status
    )
  end
end
