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
    include Aim::StampSamples

    DEFAULT = 'default'
    RESTAMP_STATUSES = %w[review on_hold ready].freeze

    before_action :require_fiscal
    before_action :set_target, except: :index

    def index
      @groups = editable_groups
      @default = Aim::StampLayout.history_for(nil).first if helpers.aim_user_admin?
      @layouts = Aim::StampLayout.where(agency_group_id: @groups.map(&:id)).order(:id).index_by(&:agency_group_id)
      redirect_to aim_root_path, alert: 'Only Fiscal and AIM admins change stamp layouts.' if @groups.empty? && !helpers.aim_user_admin?
    end

    # ?start_from= loads the default, the built-in stamp or another group's
    # layout into the designer (#229); nothing is saved until Save.
    def edit
      started = Aim::StampLayout.start_from(params[:start_from]) if params[:start_from].present?
      @start_from = params[:start_from] if started
      @layout = loaded_version || started || current_layout
      @history = Aim::StampLayout.history_for(@group).limit(20).to_a
      @samples = sample_invoices
    end

    def update
      layout = designed_layout(agency_group: @group, note: params[:note].to_s.squish.presence)
      problem = too_big(layout)
      return redirect_to(edit_target_path, alert: problem) if problem

      layout.save!
      restamped = params[:restamp] == 'fiscal' ? restamp_with_fiscal : 0
      redirect_to edit_target_path, notice: saved_notice(restamped)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to edit_target_path, alert: e.record.errors.full_messages.to_sentence
    end

    # The chosen invoice -- or a PDF the person uploaded, filled with sample
    # values -- stamped with the layout as it stands in the designer, unsaved.
    # The upload is read from its temporary file and kept nowhere. The
    # warnings ride in a header, page by page.
    def preview
      source, values = preview_source
      return head(:not_found) unless source

      result = Aim::ApprovalStamp.preview(designed_layout, source: source, values: values, check_overlap: true)
      response.headers['X-Stamp-Warnings'] = Aim::ApprovalStamp.describe(result.warnings).to_s
      send_data result.bytes, type: 'application/pdf', disposition: 'inline', filename: 'stamp-preview.pdf'
    rescue Paperboy::Pdf::Unwritable => e
      response.headers['X-Stamp-Warnings'] = "This PDF cannot be stamped: #{e.message}".truncate(300)
      head :unprocessable_content
    end

    # A group invoice's own values, exactly as its stamp would be filled, for
    # the designer's live view ("This invoice").
    def values
      invoice = sample_invoice(params[:invoice_id])
      return head :not_found unless invoice

      render json: helpers.stamp_values_data(Aim::StampFields.values(invoice))
    end

    # A sample invoice's PDF as it is now, unstamped, for the designer's page.
    def sample
      path = sample_pdf_path
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

    def designed_layout(**attributes)
      Aim::StampLayout.new(area_list: submitted_areas, page_shrink: params[:page_shrink].presence&.to_i,
                           page_position: params[:page_position].presence, created_by: current_user_email, **attributes)
    end

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
