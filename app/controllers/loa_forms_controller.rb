class LoaFormsController < ApplicationController
  def new
    @loa_form = LoaForm.new

    employee_id = session[:user]&.dig("employee_id")
    @prefill_data = build_prefill_data(employee_id)

    @agency_options = Agency.all.map { |a| [a.long_name, a.agency_id] }
    @division_options = []
    @department_options = []
    @unit_options = []

    @form_pages = [
      { title: "Employee Info" },
      { title: "Leave Details" }
    ]

    @form_logo = "/assets/images/default-logo.svg"
  end

  def create
    @event = Event.create(
      event_type: "loa",
      employee_id: params[:loa_form][:employee_id],
      event_date: params[:loa_form][:start_date]
    )

    @loa_form = LoaForm.new(loa_form_params.merge(event_id: @event.id))

    if @loa_form.save
      redirect_to root_path, notice: "Leave of Absence submitted!"
    else
      render :new
    end
  end

  private

  def loa_form_params
    params.require(:loa_form).permit(
      :employee_id, :start_date, :end_date, :reason, :approved
    )
  end
end
