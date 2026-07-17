# frozen_string_literal: true

class PcardInventoryController < ApplicationController
  include Filterable

  before_action :require_pcard_admin
  before_action :set_pcard_inventory, only: %i[edit update]

  def index
    records = filtered_scope.to_a

    # Resolve the viewer's customized column layout for this Records table and
    # sort the rows through the shared Filterable helper (see Inbox/Submissions).
    @page = RegistryTable.find('pcard').page_key
    @layout = UserSetting.for_employee(current_employee_id).layout_for(@page)
    @columns = TableColumns.resolve(@page, @layout)

    @default_sort = default_sort_key(@columns, prefer: %w[last_name])
    sort_by = params[:sort_by].presence || @default_sort
    sort_direction = params[:sort_direction] || 'asc'
    sort_configs = @columns.select(&:sortable?).index_by(&:sort_key).transform_values(&:value)

    @pcard_inventories = sort_collection(records, sort_by, sort_direction, sort_configs,
                                         default_sort: @default_sort)
  end

  def new
    @pcard_inventory = PcardInventory.new
  end

  def create
    @pcard_inventory = PcardInventory.new(pcard_inventory_params)

    if @pcard_inventory.save
      redirect_to pcard_inventory_index_path, notice: 'P-Card inventory record created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    filtered_params = pcard_inventory_params
    filtered_params.delete(:card_number) if filtered_params[:card_number].blank?

    if @pcard_inventory.update(filtered_params)
      redirect_to pcard_inventory_index_path, notice: 'P-Card inventory record updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def export
    csv_data = generate_csv(filtered_scope.order(:last_name, :first_name))
    send_data csv_data, filename: "pcard_inventory_#{Date.today}.csv", type: 'text/csv'
  end

  private

  # Row set for the index/export: search + active/canceled status buttons.
  def filtered_scope
    scope = PcardInventory.all
    scope = scope.search(params[:search]) if params[:search].present?
    case params[:filter]
    when 'active'   then scope.active
    when 'canceled' then scope.canceled
    else scope
    end
  end

  def current_employee_id
    session.dig(:user, 'employee_id')
  end

  def require_pcard_admin
    return if pcard_admin?

    redirect_to root_path, alert: 'Access denied. P-Card admin access required.'
  end

  def pcard_admin?
    current_user_group_names.include?('system_admins') ||
      current_user_group_names.include?('pcard_admin')
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
    require 'csv'
    CSV.generate(headers: true) do |csv|
      csv << [
        'Last Name', 'First Name', 'Agency/Depart', 'Division', 'Mail Stop',
        'Address', 'City', 'State', 'Zip', 'Phone',
        'Single Purchase Limit', 'Monthly Limit', 'Card Number',
        'Issued Date', 'Expiration Date', 'Canceled Date',
        'Agent', 'Company', 'Division #', 'Approver Name',
        'Org #', 'Dept Head/Agency', 'Billing Contact'
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
