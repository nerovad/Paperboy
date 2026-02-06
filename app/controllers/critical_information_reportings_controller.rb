class CriticalInformationReportingsController < ApplicationController
  # Minimal controller for the two-page template (Employee Info + Agency Info)

  def new
    @critical_information_reporting = CriticalInformationReporting.new

    employee_id = session.dig(:user, "employee_id").to_s
    @employee   = employee_id.present? ? Employee.find_by(EmployeeID: employee_id) : nil

    unless @employee
      redirect_to login_path, alert: "Please sign in to start a submission." and return
    end

    # --- Organization chain (same pattern you use now) ---
    unit        = Unit.find_by(unit_id: @employee["Unit"])
    department  = unit ? Department.find_by(department_id: unit["department_id"]) : nil
    division    = department ? Division.find_by(division_id: department["division_id"]) : nil
    agency      = division ? Agency.find_by(agency_id: division["agency_id"]) : nil

    # --- Prefill values (everything prefilled exactly like you do now) ---
    @prefill_data = {
      employee_id: @employee["EmployeeID"],
      name:        [@employee["First_Name"], @employee["Last_Name"]].compact.join(" "),
      phone:       @employee["Work_Phone"],
      email:       @employee["EE_Email"],
      agency:      agency&.agency_id,
      division:    division&.division_id,
      department:  department&.department_id,
      unit:        unit&.unit_id
    }

    # --- Select options (IDs/order match gsabss_selects_controller.js expectations) ---
    @agency_options = Agency.order(:long_name).pluck(:long_name, :agency_id)

    @division_options = if agency
      Division.where(agency_id: agency.agency_id).order(:long_name).pluck(:long_name, :division_id)
    else
      []
    end

    @department_options = if division
      Department.where(division_id: division.division_id).order(:long_name).pluck(:long_name, :department_id)
    else
      []
    end

    # Unit label = "unit_id - long_name", value = unit_id (your current pattern)
    @unit_options = if department
      Unit.where(department_id: department.department_id)
          .order(:unit_id)
          .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
    else
      []
    end

    # Employee dropdown options (for Pages 4+)
    @employee_options = Employee.select(:EmployeeID, :First_Name, :Last_Name)
                                .order(:Last_Name, :First_Name)
                                .map { |e| ["#{e.First_Name} #{e.Last_Name}", e.EmployeeID] }
    
    # Load location options
    @location_options = load_location_options
  end

  def show
    @critical_information_reporting = CriticalInformationReporting.includes(:status_changes).find(params[:id])
    @status_changes = @critical_information_reporting.status_changes.chronological
  end

  def pdf
    @critical_information_reporting = CriticalInformationReporting.find(params[:id])
    pdf_data = CriticalInformationPdfGenerator.generate(@critical_information_reporting)

    send_data pdf_data,
              filename: "CriticalInformationReport_#{@critical_information_reporting.id}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end

  def download_media
    @critical_information_reporting = CriticalInformationReporting.find(params[:id])

    if @critical_information_reporting.media.attached?
      redirect_to rails_blob_path(@critical_information_reporting.media, disposition: "attachment")
    else
      redirect_to inbox_queue_path, alert: "No media attachment found."
    end
  end

  def edit
    @critical_information_reporting = CriticalInformationReporting.find(params[:id])

    employee_id = session.dig(:user, "employee_id").to_s
    @employee = employee_id.present? ? Employee.find_by(EmployeeID: employee_id) : nil

    unless @employee
      redirect_to login_path, alert: "Please sign in." and return
    end

    # Load organization options (same as new action)
    @agency_options = Agency.order(:long_name).pluck(:long_name, :agency_id)

    agency = Agency.find_by(agency_id: @critical_information_reporting.agency)
    @division_options = agency ? Division.where(agency_id: agency.agency_id).order(:long_name).pluck(:long_name, :division_id) : []

    division = Division.find_by(division_id: @critical_information_reporting.division)
    @department_options = division ? Department.where(division_id: division.division_id).order(:long_name).pluck(:long_name, :department_id) : []

    department = Department.find_by(department_id: @critical_information_reporting.department)
    @unit_options = if department
      Unit.where(department_id: department.department_id)
          .order(:unit_id)
          .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
    else
      []
    end

    @employee_options = Employee.select(:EmployeeID, :First_Name, :Last_Name)
                                .order(:Last_Name, :First_Name)
                                .map { |e| ["#{e.First_Name} #{e.Last_Name}", e.EmployeeID] }

    @location_options = load_location_options
  end

  def update
    @critical_information_reporting = CriticalInformationReporting.find(params[:id])

    if @critical_information_reporting.update(critical_information_reporting_params)
      redirect_to inbox_queue_path, notice: "Critical Information Report updated successfully."
    else
      # Reload options on failure
      @agency_options = Agency.order(:long_name).pluck(:long_name, :agency_id)

      agency = Agency.find_by(agency_id: @critical_information_reporting.agency)
      @division_options = agency ? Division.where(agency_id: agency.agency_id).order(:long_name).pluck(:long_name, :division_id) : []

      division = Division.find_by(division_id: @critical_information_reporting.division)
      @department_options = division ? Department.where(division_id: division.division_id).order(:long_name).pluck(:long_name, :department_id) : []

      department = Department.find_by(department_id: @critical_information_reporting.department)
      @unit_options = if department
        Unit.where(department_id: department.department_id)
            .order(:unit_id)
            .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
      else
        []
      end

      @employee_options = Employee.select(:EmployeeID, :First_Name, :Last_Name)
                                  .order(:Last_Name, :First_Name)
                                  .map { |e| ["#{e.First_Name} #{e.Last_Name}", e.EmployeeID] }

      @location_options = load_location_options

      render :edit, status: :unprocessable_entity
    end
  end

  def update_status
    @critical_information_reporting = CriticalInformationReporting.find(params[:id])
    new_status = params[:status]

    if CriticalInformationReporting.statuses.keys.include?(new_status)
      @critical_information_reporting.update!(status: new_status)

      redirect_to inbox_queue_path, notice: "Critical Information Report status updated to #{new_status.titleize}."
    else
      redirect_to inbox_queue_path, alert: "Invalid status."
    end
  end

  def approve
    @critical_information_reporting = CriticalInformationReporting.find(params[:id])

    @critical_information_reporting.update!(status: :resolved)

    redirect_to inbox_queue_path, notice: "Critical Information Report marked as resolved."
  end

  def deny
    @critical_information_reporting = CriticalInformationReporting.find(params[:id])

    reason = params[:denial_reason].to_s.strip

    @critical_information_reporting.update!(status: :cancelled)

    redirect_to inbox_queue_path, alert: "Critical Information Report cancelled."
  end

  def create
    employee      = session[:user]
    employee_id   = employee&.dig("employee_id").to_s

    @critical_information_reporting = CriticalInformationReporting.new(critical_information_reporting_params)
    @critical_information_reporting.employee_id = employee_id if @critical_information_reporting.respond_to?(:employee_id=)

    if @critical_information_reporting.save
      NotifyTeamsJob.perform_later(@critical_information_reporting.id) if @critical_information_reporting.immediate_urgency?
      redirect_to form_success_path, allow_other_host: false, status: :see_other
    else
      # Rebuild options on failure (same as in new)
      # (We intentionally repeat the logic to keep this template self-contained.)
      emp = employee_id.present? ? Employee.find_by(EmployeeID: employee_id) : nil
      unit        = emp ? Unit.find_by(unit_id: emp["Unit"]) : nil
      department  = unit ? Department.find_by(department_id: unit["department_id"]) : nil
      division    = department ? Division.find_by(division_id: department["division_id"]) : nil
      agency      = division ? Agency.find_by(agency_id: division["agency_id"]) : nil

      @prefill_data = {
        employee_id: emp&.[]("EmployeeID"),
        name:        emp ? [emp["First_Name"], emp["Last_Name"]].compact.join(" ") : nil,
        phone:       emp&.[]("Work_Phone"),
        email:       emp&.[]("EE_Email"),
        agency:      agency&.agency_id,
        division:    division&.division_id,
        department:  department&.department_id,
        unit:        unit&.unit_id
      }

      @agency_options = Agency.order(:long_name).pluck(:long_name, :agency_id)
      @division_options = agency ? Division.where(agency_id: agency.agency_id).order(:long_name).pluck(:long_name, :division_id) : []
      @department_options = division ? Department.where(division_id: division.division_id).order(:long_name).pluck(:long_name, :department_id) : []
      @unit_options = if department
        Unit.where(department_id: department.department_id)
            .order(:unit_id)
            .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
      else
        []
      end

      # CRITICAL: Reload employee and location options for Pages 4+ when validation fails
      @employee_options = Employee.select(:EmployeeID, :First_Name, :Last_Name)
                                  .order(:Last_Name, :First_Name)
                                  .map { |e| ["#{e.First_Name} #{e.Last_Name}", e.EmployeeID] }
      
      @location_options = load_location_options

      render :new, status: :unprocessable_entity
    end
  end

  private

  def critical_information_reporting_params
    raw = params.require(:critical_information_reporting).permit(
      :employee_id, :name, :phone, :email,
      :agency, :division, :department, :unit,
      :incident_type, :incident_details, :cause,
      :impact_started, :location,
      :urgency,
      :impact, :impacted_customers, :next_steps, :media,
      staff_involved: []
    )

    # Normalize multi-select array into comma-separated string
    raw[:staff_involved] = Array(raw[:staff_involved]).reject(&:blank?).join(",")

    raw
  end

  def load_location_options
    [
      'AGOURA-899 N. KANAN RD.',
      'CAMARILLO-106 DURLEY AVE.',
      'CAMARILLO-1203 FLYNN RD. UNIT 220',
      'CAMARILLO-1401 AVIATION DR.',
      'CAMARILLO-1401 AVIATION DR. V 20',
      'CAMARILLO-160 DURLEY AVE.',
      'CAMARILLO-165 DURLEY AVE.',
      'CAMARILLO-1722 LEWIS RD.',
      'CAMARILLO-1732 LEWIS RD.',
      'CAMARILLO-1736 S. LEWIS RD.',
      'CAMARILLO-1750 LEWIS RD.',
      'CAMARILLO-1756 S. LEWIS',
      'CAMARILLO-1758 LEWIS RD. CASA E',
      'CAMARILLO-1760 LEWIS RD. CASA D',
      'CAMARILLO-189 S. LAS POSAS RD.',
      'CAMARILLO-2160 PICKWICK DR.',
      'CAMARILLO-295 WILLIS AVE',
      'CAMARILLO-3100 PONDEROSA DR .',
      'CAMARILLO-3100 PONDEROSA DR.',
      'CAMARILLO-333 SKYWAY DR.',
      'CAMARILLO-345 SKYWAY DR.',
      'CAMARILLO-350 WILLIS AVE.',
      'CAMARILLO-355 POST ST.',
      'CAMARILLO-3701 LAS POSAS RD.',
      'CAMARILLO-375 DURLEY AVE.',
      'CAMARILLO-3760 CALLE TECATE',
      'CAMARILLO-3801 LAS POSAS STE 214',
      'CAMARILLO-403 VALLEY VISTA DR.',
      'CAMARILLO-465 HORIZON CIR.',
      'CAMARILLO-5171 VERDUGO WAY',
      'CAMARILLO-5353 SANTA ROSA RD.',
      'CAMARILLO-555 AIRPORT WAY',
      'CAMARILLO-600 AVIATION DR.',
      'CAMRILLO-102 DURLEY AVE.',
      'FILLMORE-3824 GUIBERSON RD.',
      'FILLMORE-502 2ND STREET',
      'FILLMORE-524 SESPE AVE.',
      'FILLMORE-613 OLD TELEGRAPH RD',
      'FILLMORE-823 NORTH OAK AVENUE',
      'FILLMORE-828 W. VENTURA ST.',
      'FRAZIER PARK-15011 LOCKWOOD VALLEY RD.',
      'FRAZIER PARK-15031 LOCKWOOD VALLEY RD',
      'FRAZIER PARK-15051 LOCKWOOD VALLEY RD.',
      'MALIBU-11855 PACIFIC COAST HWY (PCH)',
      'MALIBU-928 LATIGO CANYON RD.',
      'MOORPARK-11501 CHAMPIONSHIP DR.',
      'MOORPARK-15698 1/2 CAMPUS PARK DR.',
      'MOORPARK-295 E. HIGH STREET',
      'MOORPARK-4185 CEDAR SPRINGS',
      'MOORPARK-610 SPRING RD.',
      'MOORPARK-612 SPRING RD BLDG A',
      'MOORPARK-612 SPRING RD.',
      'MOORPARK-6767 SPRING RD. BLDG A',
      'MOORPARK-6767 SPRING RD. BLDG B',
      'MOORPARK-6767 SPRING RD. BLDG C',
      'MOORPARK-699 MOORPARK AVEE',
      'MOORPARK-7150 WALNUT CANYON RD.',
      'MOORPARK-9550 LOS ANGELES AVE',
      'NEWBURY PARK-2400 CONEJO SPECTRUM ST.',
      'NEWBURY PARK-2500 W HILL CREST DR.',
      'NEWBURY PARK-751 MITCHELL RD.',
      'NEWBURY PARK-830 S. REINO RD',
      'OAK PARK-855 DEERHILL RD',
      'OAK VIEW-15 KUNKLE ST',
      'OAK VIEW-18 VALLEY RD.',
      'OJAI-111 E OJAI AVE.',
      'OJAI-12000 OJAI SANTA PAULA RD.',
      'OJAI-1201 E OJAI RD',
      'OJAI-1768 MARICOPA HIGHWAY',
      'OJAI-400 S LOMITA AVE.',
      'OJAI-402 S. VENTURA ST.',
      'OJAI-466 S LA LUNA',
      'OJAI-555 MAHONEY AVE',
      'OXNARD-1051 YARNELL PLACE',
      'OXNARD-133 C ST.',
      'OXNARD-1400 VANGUARD RD.',
      'OXNARD-1701 PACIFIC AVE. #110',
      'OXNARD-1701 SOLAR DR.',
      'OXNARD-1721 PACIFIC AVE.',
      'OXNARD-1801 SOLAR DR.',
      'OXNARD-1911 WILLIAMS DR.',
      'OXNARD-2000 OUTLET CENTER DR.',
      'OXNARD-2130 VENTURA RD.',
      'OXNARD-2220 E. GONZALES RD.',
      'OXNARD-2240 E.GONZALES',
      'OXNARD-2400 SOUTH C ST.',
      'OXNARD-2420 CELSIUS AVE, UNIT A & B',
      'OXNARD-2431 LATIGO AVE.',
      'OXNARD-2451 LATIGO AVE.',
      'OXNARD-2471 LATIGO AVE.',
      'OXNARD-2500 SOUTH C ST. STE A & B',
      'OXNARD-2500 SOUTH C ST., STE C & D',
      'OXNARD-2643 SAVIERS RD.',
      'OXNARD-2697 SAVIERS RD (2697 "C" ST).',
      'OXNARD-2791 PARK VIEW COURT',
      'OXNARD-2820 JOURDAN ST.',
      'OXNARD-2901 VENTURA RD. 2ND/3RD FLOOR',
      'OXNARD-3100 N. ROSE AVE',
      'OXNARD-325 W. CHANNEL ISLANDS BLVD.',
      'OXNARD-3302 TURNOUT CIRCLE',
      'OXNARD-3334 SANTA CLARA AVE',
      'OXNARD-341 BERNOULLI CIR.',
      'OXNARD-4000 ROSE AVE.',
      'OXNARD-411/451 PLEASANT VALLEY RD',
      'OXNARD-4333 VINEYARD AVE.',
      'OXNARD-4353 VINEYARD',
      'OXNARD-545 CENTRAL AVE.',
      'OXNARD-545/555 SOUTH A ST.',
      'PIRU-2815 TELEGRAPH RD.',
      'PIRU-3811 CENTER ST.',
      'PIRU-3977 CENTER ST',
      'PIRU-513 N CHURCH ST',
      'PORT HUENEME-304 2ND ST.',
      'PORT HUENEME-510 PARK AVE .',
      'SANTA PAULA-114 S. 10TH ST.',
      'SANTA PAULA-12391 W. TELEGRAPH RD',
      'SANTA PAULA-12727 OJAI RD',
      'SANTA PAULA-1334 E. MAIN ST.',
      'SANTA PAULA-254 W. HARVARD BLVD.',
      'SANTA PAULA-536 W MAIN ST.',
      'SANTA PAULA-600 S TODD RD.',
      'SANTA PAULA-620 W. HARVARD BLVD',
      'SANTA PAULA-630 TODD RD',
      'SANTA PAULA-725 E. MAIN ST.',
      'SANTA PAULA-815 SANTA BARBARA ST.',
      'SANTA PAULA-821 SANTA BARBARA ST.',
      'SANTA PAULA-RED MOUNTAIN',
      'SATICOY-11201-A RIVERBANK DR.',
      'SATICOY-11251-B RIVERBANK DR.',
      'SATICOY-11321 VIOLETA RD',
      'SIMI VALLEY-1050 COUNTRY CLUB DR.',
      'SIMI VALLEY-1133-B LOS ANGELES AVE.',
      'SIMI VALLEY-1227 E. LOS ANGELES AVE.',
      'SIMI VALLEY-1900 Los Angeles Ave',
      'SIMI VALLEY-1910 CHURCH ST',
      'SIMI VALLEY-2003 ROYAL AVE.',
      'SIMI VALLEY-2639 AVENIDA AVE',
      'SIMI VALLEY-2900 MADERA RD.',
      'SIMI VALLEY-2901 ERRINGER RD,',
      'SIMI VALLEY-2969 TAPO CANYON RD.',
      'SIMI VALLEY-3150 E LOS ANGELES AVE.',
      'SIMI VALLEY-3265 N TAPO CYN',
      'SIMI VALLEY-3855 ALAMO ST.',
      'SIMI VALLEY-4322 EILEEN ST.',
      'SIMI VALLEY-5874 E. LOS ANGELES AVE.',
      'SIMI VALLEY-670 W LA AVE.',
      'SIMI VALLEY-7535 SANTA SUSANA RD.',
      'SIMI VALLEY-790 PACIFIC AVE',
      'SIMI VALLEY-970 ENCHANTED WAY',
      'SIMI VALLEY-980 ENCHANTED WAY',
      'SOMIS-3356 SOMIS RD',
      'THOUSAND OAKS-125 W. THOUSAND OAKS BLVD',
      'THOUSAND OAKS-151 DUESENBERG DR',
      'THOUSAND OAKS-2010 UPPER RANCH RD.',
      'THOUSAND OAKS-2100 E. T.O. BLVD',
      'THOUSAND OAKS-2101 E. OLSEN RD',
      'THOUSAND OAKS-2967 E. THOUSAND OAKS BLVD.',
      'THOUSAND OAKS-2977 MOUNTCLEFF BLVD',
      'THOUSAND OAKS-325 W HILLCREST DR',
      'THOUSAND OAKS-33 LAKE SHERWOOD DR.',
      'THOUSAND OAKS-555 AVENIDA DE LOS ARBOLES',
      'THOUSAND OAKS-625 HILLCREST DR.',
      'THOUSAND OAKS-80 E. HILLCREST DR.',
      'VENTURA-1000 S. HILL RD.',
      'VENTURA-1001 PARTRIDGE DR.',
      'VENTURA-1033 E. MAIN ST.',
      'VENTURA-1070 HILL RD. STE 1',
      'VENTURA-11220 AZAHAR ST.',
      'VENTURA-1190 S VICTORIA AVE UNIT 200',
      'VENTURA-1292 LOS ANGELES AVE',
      'VENTURA-133 W. SANTA CLARA ST',
      'VENTURA-180 CANADA LARGA',
      'VENTURA-1957 EASTMAN AVE.',
      'VENTURA-2189 EASTMAN AVE.',
      'VENTURA-2323 KNOLL DR.',
      'VENTURA-2575 VISTA DEL MAR',
      'VENTURA-2982 MARTHA DR',
      'VENTURA-3100 FOOTHILL RD.',
      'VENTURA-3147 LOMA VISTA RD.',
      'VENTURA-3160 LOMA VISTA RD',
      'VENTURA-3170 LOMA VISTA RD',
      'VENTURA-3180 LOMA VISTA RD',
      'VENTURA-384 HILLMONT AVE.',
      'VENTURA-4245 MARKET STREET',
      'VENTURA-4258 TELEGRAPH',
      'VENTURA-4567 TELEPHONE RD',
      'VENTURA-4601 TELEPHONE RD.',
      'VENTURA-4651 TELEPHONE RD',
      'VENTURA-5600 EVERGLADES ST. UNIT A & B',
      'VENTURA-57 DAY RD.',
      'VENTURA-5720 RALSTON STE 300',
      'VENTURA-5740 RALSTON- HCA',
      'VENTURA-5777 N. VENTURA AVE.',
      'VENTURA-5850 THILLE RD',
      'VENTURA-5851 THILLE ST.',
      'VENTURA-606 N. VENTURA AVE',
      'VENTURA-6401 TELEPHONE RD.',
      'VENTURA-646 COUNTY SQUARE DR.',
      'VENTURA-651 MAIN ST.',
      'VENTURA-669 COUNTY SQ DR',
      'VENTURA-67 E BARNETT ST',
      'VENTURA-77 CALIFORNIA ST.',
      'VENTURA-789 VICTORIA AVE',
      'VENTURA-800 S VICTORIA AVE',
      'VENTURA-800 S VICTORIA AVE (HOA)',
      'VENTURA-800 S. VICTORIA AVE (HOJ)',
      'VENTURA-800 S. VICTORIA AVE (PTDF)',
      'VENTURA-800 S. VICTORIA AVE (PTDF Annex)',
      'VENTURA-800 S. VICTORIA AVE (Service Building)',
      'VENTURA-855 PARTRIDGE DR.',
      'VENTURA-950 COUNTY SQUARE DR.',
      'VENTURA-RINCON-5674 W. PACIFIC COAST HWY-PCH'
    ]
  end
end
