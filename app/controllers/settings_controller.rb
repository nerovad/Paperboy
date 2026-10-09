# frozen_string_literal: true

class SettingsController < ApplicationController
  def show
    @settings = current_user_settings
    load_subscriptions
    load_away_cover
  end

  def update
    @settings = current_user_settings
    if @settings.update(settings_params)
      redirect_to settings_path, notice: 'Settings saved.'
    else
      load_subscriptions
      load_away_cover
      render :show, status: :unprocessable_entity
    end
  end

  # Persist a customized column/filter layout for one page (:inbox or
  # :submissions). Called by the column-customizer Stimulus controller; the page
  # reloads afterwards so the server re-renders columns + filters.
  def table_layout
    page = params[:page].to_s
    return head :bad_request unless TableColumns.valid_page?(page)

    fields = table_layout_fields
    if current_user_settings.set_layout(page, fields)
      head :no_content
    else
      head :unprocessable_entity
    end
  end

  # Takes one form off this person's sidebar, or puts it back. Reached from a
  # row in the Form Library. Only a form they may open can be named: the list
  # is theirs, but it is not somewhere to park arbitrary strings.
  def sidebar_form
    catalog = FormCatalog.new(admin: helpers.system_admin?,
                              permitted_keys: current_user_form_permission_keys)
    form_key = params[:form_key].to_s
    return head :bad_request unless catalog.forms.any? { |name, _| catalog.key_for(name) == form_key }

    current_user_settings.set_form_hidden(form_key, params[:hidden] == '1')
    redirect_back fallback_location: form_library_path
  end

  # Stars one search as this person's Paperboy start page. Reached from the
  # star beside the sidebar's search-mode button.
  def default_search
    mode = params[:mode].to_s
    return head :bad_request unless UserSetting::SEARCH_MODES.include?(mode)

    settings = current_user_settings
    settings.default_search_mode = mode
    settings.save
    redirect_back fallback_location: forms_home_path
  end

  private

  # Normalize the incoming ordered field list into plain strings / hashes for
  # TableColumns.sanitize_layout. Each entry is either a built-in key string or
  # a custom descriptor { type:"field", form:, field:, label: }.
  def table_layout_fields
    Array(params[:fields]).map do |entry|
      if entry.respond_to?(:permit)
        entry.permit(:type, :form, :field, :label).to_h
      else
        entry.to_s
      end
    end
  end

  # This person's own form subscriptions, the group subscriptions that reach
  # them, and the catalog the picker needs. Group rows are listed read-only:
  # they belong to the group's ACL page, and one member cannot unsubscribe the
  # rest -- only opt themselves out.
  def load_subscriptions
    employee_id = session.dig(:user, 'employee_id').to_s
    @form_subscriptions = Forms::Subscription.for_employee(employee_id).includes(:group).ordered.to_a
    @group_subscriptions = Forms::Subscription.reaching_member(employee_id).includes(:group).ordered.to_a
    @opted_out_subscription_ids = Forms::SubscriptionOptOut.where(employee_id: employee_id,
                                                                  form_subscription: @group_subscriptions)
                                                           .pluck(:form_subscription_id).to_set
    @subscription_form_types = Forms::Subscription.form_type_catalog
    @subscription_form_labels = @subscription_form_types.to_h { |form| [form[:class_name], form[:label]] }
  end

  # Away cover for this person, plus the colleagues they can hand work to.
  # Everyone is offered: cover is routinely a peer or a manager rather than
  # anyone in the reporting chain.
  def load_away_cover
    employee_id = session.dig(:user, 'employee_id').to_s
    @away_periods = AwayPeriod.for_employee(employee_id).chronological.to_a
    @delegate_options = Employee.where.not(id: employee_id)
                                .order(:last_name, :first_name)
                                .pluck(:last_name, :first_name, :id)
                                .map { |last, first, id| [Employee.format_sort_name(first, last), id] }
  end

  def current_user_settings
    employee_id = session.dig(:user, 'employee_id')
    UserSetting.find_or_initialize_by(employee_id: employee_id)
  end

  def settings_params
    params.require(:user_setting).permit(:inbox_email_notifications)
  end
end
