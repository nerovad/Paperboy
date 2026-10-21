# frozen_string_literal: true

module Aim
  # The stamp designer (#221): each agency group's approval stamp -- one or
  # more stamp areas, dragged into place on a sample invoice's page -- and
  # the default for groups with none. A group's Fiscal edit its own; AIM
  # Admins edit any group's and the default.
  #
  # Saving makes a new version (Aim::StampLayout is append-only) and asks
  # which invoices take it: those still with Fiscal are stamped again, or
  # only new approvals. Checking a layout on a real invoice writes nothing.
  class StampLayoutsController < BaseController
    include Aim::StoredPdf

    DEFAULT = 'default'
    RESTAMP_STATUSES = %w[review on_hold ready].freeze
    SAMPLE_LIMIT = 25

    before_action :require_fiscal
    before_action :set_target, except: :index

    def index
      @groups = editable_groups
      @default = Aim::StampLayout.history_for(nil).first if helpers.aim_user_admin?
      @layouts = Aim::StampLayout.where(agency_group_id: @groups.map(&:id)).order(:id).index_by(&:agency_group_id)
      redirect_to aim_root_path, alert: 'Only Fiscal and AIM admins change stamp layouts.' if @groups.empty? && !helpers.aim_user_admin?
    end

    def edit
      @layout = loaded_version || current_layout
      @history = Aim::StampLayout.history_for(@group).limit(20).to_a
      @samples = sample_invoices
    end

    def update
      layout = Aim::StampLayout.new(agency_group: @group, area_list: submitted_areas, note: params[:note].to_s.squish.presence,
                                    created_by: current_user_email)
      problem = too_big(layout)
      return redirect_to(edit_target_path, alert: problem) if problem

      layout.save!
      restamped = params[:restamp] == 'fiscal' ? restamp_with_fiscal : 0
      redirect_to edit_target_path, notice: saved_notice(restamped)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to edit_target_path, alert: e.record.errors.full_messages.to_sentence
    end

    # The chosen invoice stamped with the layout as it stands in the designer,
    # unsaved. The warnings ride in a header, page by page.
    def preview
      invoice = sample_invoice(params[:invoice_id])
      source = invoice && store_file(invoice, 'pdf')
      return head :not_found unless source

      layout = Aim::StampLayout.new(area_list: submitted_areas, created_by: current_user_email)
      values = params[:worst_case] == '1' ? Aim::StampFields.worst_case : Aim::StampFields.values(invoice)
      result = Aim::ApprovalStamp.preview(invoice, layout, values: values, source: source, check_overlap: true)
      response.headers['X-Stamp-Warnings'] = Aim::ApprovalStamp.describe(result.warnings).to_s
      send_data result.bytes, type: 'application/pdf', disposition: 'inline', filename: 'stamp-preview.pdf'
    rescue Paperboy::Pdf::Unwritable => e
      response.headers['X-Stamp-Warnings'] = "This PDF cannot be stamped: #{e.message}".truncate(300)
      head :unprocessable_content
    end

    # A sample invoice's PDF as it is now, unstamped, for the designer's page.
    def sample
      invoice = sample_invoice(params[:invoice_id])
      path = invoice && store_file(invoice, 'pdf')
      return head :not_found unless path

      send_file path, type: 'application/pdf', disposition: 'inline'
    end

    private

    def editable_groups
      return helpers.aim_agency_groups.all if helpers.aim_user_admin?

      helpers.aim_groups_held(%w[fiscal])
    end

    def set_target
      key = params[:id].to_s
      if key == DEFAULT
        @group = nil
        return if helpers.aim_user_admin?
      else
        @group = editable_groups.find { |group| group.id.to_s == key }
        return if @group
      end
      redirect_to aim_stamp_layouts_path, alert: 'That stamp layout is not one you can change.'
    end

    def target_key = @group&.id || DEFAULT

    def edit_target_path = edit_aim_stamp_layout_path(target_key)

    def current_layout
      @group ? Aim::StampLayout.current_for(@group) : (Aim::StampLayout.history_for(nil).first || Aim::StampLayout.built_in)
    end

    def loaded_version
      Aim::StampLayout.history_for(@group).find_by(id: params[:version]) if params[:version].present?
    end

    def submitted_areas
      list = JSON.parse(params[:areas].to_s)
      list.is_a?(Array) ? list.grep(Hash).first(Aim::StampLayout::MAX_AREAS + 1) : []
    rescue JSON::ParserError
      []
    end

    # The group's invoices (any, for the default), newest first, that have a
    # PDF: what the designer offers to lay the stamp on.
    def sample_scope
      scope = @group ? helpers.aim_agency_groups.invoices([@group]) : Aim::Invoice.all
      scope.where.not(state: %w[deleted split]).where(pdf_purged_at: nil)
    end

    def sample_invoices = sample_scope.order(id: :desc).limit(SAMPLE_LIMIT).to_a

    def sample_invoice(id) = id.present? ? sample_scope.find_by(id: id) : sample_scope.order(id: :desc).first

    def too_big(layout)
      box = layout.oversized_area(Aim::StampFields.worst_case) or return

      "Not saved: the stamp area starting \"#{box.lines.first.to_s.truncate(40)}\" is too big for the page even at the " \
        'smallest text size. Take some rows out or make it narrower.'
    end

    # Invoices of the groups this layout stamps, still with Fiscal: stamped
    # again by StampApprovedJob, which finds them by stamped_at. Their old
    # stamped copy shows until the new one replaces it.
    def restamp_with_fiscal
      groups = @group ? [@group] : helpers.aim_agency_groups.all.reject { |group| Aim::StampLayout.history_for(group).exists? }
      records = Aim::FiscalRecord.served_by(helpers.aim_agency_groups.invoices(groups)).where(status: RESTAMP_STATUSES)
      ids = records.pluck(:invoice_id)
      records.update_all(stamped_at: nil, stamp_error: nil)
      ids.each { |id| Aim::StampApprovedJob.perform_later(id) }
      ids.size
    end

    def saved_notice(restamped)
      return 'Stamp layout saved. New approvals take it.' if params[:restamp] != 'fiscal'

      "Stamp layout saved. #{helpers.pluralize(restamped, 'invoice')} still with Fiscal will be stamped again."
    end
  end
end
