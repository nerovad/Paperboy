# frozen_string_literal: true

module Aim
  # Loading a lookup file on screen (item b.3): upload, see the report,
  # accept any row the COA objects to, apply, and undo. Fiscal and AIM
  # Admins. The file is kept on the import row between preview and apply.
  class CodingImportsController < BaseController
    before_action :require_fiscal
    before_action :set_import, only: %i[show apply undo destroy]
    KINDS = %w[add edit unchanged refused].freeze

    def index
      @imports = Aim::CodingImport.newest_first.to_a
    end

    # A CSV to fill in: the headings the reader expects, and one example row.
    def template
      csv = CSV.generate do |out|
        out << Aim::LookupFile::TEMPLATE
        out << Aim::LookupFile::EXAMPLE
      end
      send_data csv, filename: 'AIM_Lookup_Template.csv', type: 'text/csv', disposition: 'attachment'
    end

    # The agencies AIM works (AIM's Budget Units), not the whole COA.
    def new
      @units = Aim::Units.new
      @agencies = @units.agencies
    end

    # Reads the file and keeps it with its report: nothing is loaded yet.
    def create
      file = params[:file]
      return redirect_to(new_aim_coding_import_path, alert: 'Choose a CSV file.') if file.blank?

      import = Aim::CodingImport.new(agency: params[:agency].to_s.upcase, file_name: file.original_filename.to_s,
                                     imported_by: current_user_email, effective_option: effective_option,
                                     effective_from: effective_date, default_unit: params[:default_unit].presence,
                                     file_content: file.read, status: 'previewed')
      import.with_file { |path| import.report = lookup(import, path).report }
      import.save!
      replaced = Aim::CodingImport.find_by(id: params[:replaces], status: 'previewed')
      replaced&.destroy
      redirect_to aim_coding_import_path(import)
    rescue CSV::MalformedCSVError, ArgumentError => e
      redirect_to new_aim_coding_import_path, alert: "That file could not be read: #{e.message}"
    end

    # An import made before previews kept row detail is re-read from its file
    # when there is one; a command-line import has none to re-read.
    def show
      @report = @import.report || {}
      if !@report.key?('all_rows') && @import.file_content.present?
        @import.with_file { |path| @import.update!(report: lookup(@import, path).report) }
        @report = @import.report
      end
      @only = KINDS.include?(params[:only]) ? params[:only] : nil
    end

    # An import that loaded nothing (previewed, or undone) can go; an applied
    # one is undone first, so its rules always have their history.
    def destroy
      return redirect_to(aim_coding_import_path(@import), alert: 'Undo this import first; then it can be deleted.') if @import.applied?

      Aim::CodingImport.transaction do
        Aim::CodingRule.where(import_id: @import.id).update_all(import_id: nil)
        Aim::CodingRule.where(retired_by_import_id: @import.id).update_all(retired_by_import_id: nil)
        @import.destroy!
      end
      redirect_to aim_coding_imports_path, notice: 'Import deleted.'
    end

    def apply
      return redirect_to(aim_coding_import_path(@import), alert: 'This import was already applied.') unless @import.previewed?

      accept = Array(params[:accept_rows]).map(&:to_i)
      @import.with_file { |path| lookup(@import, path, accept: accept).apply!(by: current_user_email, import: @import) }
      redirect_to aim_coding_import_path(@import), notice: "Loaded #{@import.loaded_count} rules."
    rescue ArgumentError => e
      redirect_to aim_coding_import_path(@import), alert: e.message
    end

    def undo
      @import.undo!(by: current_user_email)
      redirect_to aim_coding_import_path(@import), notice: 'Undone: its rules are retired and the ones it replaced are back.'
    rescue ArgumentError => e
      redirect_to aim_coding_import_path(@import), alert: e.message
    end

    private

    def set_import
      @import = Aim::CodingImport.find(params[:id])
    end

    def lookup(import, path, accept: :none)
      Aim::LookupImport.new(path, agency: import.agency, effective: import.effective_option,
                                  effective_date: import.effective_from, budget_unit: import.default_unit, accept: accept)
    end

    def effective_option
      Aim::CodingImport::EFFECTIVE_OPTIONS.include?(params[:effective]) ? params[:effective] : 'bdo'
    end

    def effective_date
      Date.parse(params[:effective_date]) if effective_option == 'date' && params[:effective_date].present?
    end
  end
end
