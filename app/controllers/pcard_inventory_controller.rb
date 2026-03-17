class PcardInventoryController < ApplicationController
  before_action :require_pcard_admin
  before_action :set_pcard_inventory, only: [:edit, :update]

  def index
    @pcard_inventories = PcardInventory.order(:last_name, :first_name)

    if params[:search].present?
      @pcard_inventories = @pcard_inventories.search(params[:search])
    end

    case params[:filter]
    when "active"
      @pcard_inventories = @pcard_inventories.active
    when "canceled"
      @pcard_inventories = @pcard_inventories.canceled
    end
  end

  def new
    @pcard_inventory = PcardInventory.new
  end

  def create
    @pcard_inventory = PcardInventory.new(pcard_inventory_params)

    if @pcard_inventory.save
      redirect_to pcard_inventory_index_path, notice: "P-Card inventory record created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    filtered_params = pcard_inventory_params
    filtered_params.delete(:card_number) if filtered_params[:card_number].blank?

    if @pcard_inventory.update(filtered_params)
      redirect_to pcard_inventory_index_path, notice: "P-Card inventory record updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def export
    @pcard_inventories = PcardInventory.order(:last_name, :first_name)

    if params[:filter] == "active"
      @pcard_inventories = @pcard_inventories.active
    elsif params[:filter] == "canceled"
      @pcard_inventories = @pcard_inventories.canceled
    end

    csv_data = generate_csv(@pcard_inventories)
    send_data csv_data, filename: "pcard_inventory_#{Date.today}.csv", type: "text/csv"
  end

  private

  def require_pcard_admin
    unless pcard_admin?
      redirect_to root_path, alert: "Access denied. P-Card admin access required."
    end
  end

  def pcard_admin?
    current_user_group_names.include?("system_admins") ||
      current_user_group_names.include?("pcard_admin")
  end

  def set_pcard_inventory
    @pcard_inventory = PcardInventory.find(params[:id])
  end

  def pcard_inventory_params
    params.require(:pcard_inventory).permit(
      :last_name, :first_name, :agency, :division, :mail_stop,
      :address, :city, :state, :zip, :phone,
      :single_purchase_limit, :monthly_limit, :card_number,
      :issued_date, :expiration_date, :canceled_date,
      :agent, :company, :division_number, :approver_name,
      :org_number, :dept_head_agency, :billing_contact
    )
  end

  def generate_csv(records)
    require "csv"
    CSV.generate(headers: true) do |csv|
      csv << [
        "Last Name", "First Name", "Agency/Depart", "Division", "Mail Stop",
        "Address", "City", "State", "Zip", "Phone",
        "Single Purchase Limit", "Monthly Limit", "Card Number",
        "Issued Date", "Expiration Date", "Canceled Date",
        "Agent", "Company", "Division #", "Approver Name",
        "Org #", "Dept Head/Agency", "Billing Contact"
      ]
      records.each do |r|
        csv << [
          r.last_name, r.first_name, r.agency, r.division, r.mail_stop,
          r.address, r.city, r.state, r.zip, r.phone,
          r.single_purchase_limit, r.monthly_limit, r.masked_card_number,
          r.issued_date, r.expiration_date, r.canceled_date,
          r.agent, r.company, r.division_number, r.approver_name,
          r.org_number, r.dept_head_agency, r.billing_contact
        ]
      end
    end
  end
end
