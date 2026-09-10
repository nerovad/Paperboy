# frozen_string_literal: true

# The histories a submission keeps, rendered as HTML fragments the inbox modal
# fetches on demand — so a queue of a hundred rows carries no history markup
# until somebody asks for one.
#
# Two of them today, both addressed by class name and id rather than by route,
# because the inbox lists every form type in one table:
#
# * status — the workflow timeline (StatusChange), for forms whose template
#   enables the "Status History" button;
# * edits — the field-level audit trail (RecordEdit), which is not configurable
#   at all. It rides along with the Edit button everywhere that appears, so any
#   form that can be edited can be audited without anyone switching it on.
class SubmissionHistoriesController < ApplicationController
  def status
    record = history_subject(TrackableStatus)
    return if performed?

    render partial: 'submissions/status_timeline',
           locals: { status_changes: record.status_timeline.to_a, item_id: fragment_id(record) },
           layout: false
  end

  def edits
    record = history_subject(AuditableEdits, editable: true)
    return if performed?

    render partial: 'submissions/edit_timeline',
           locals: { entries: Forms::EditTrail.for(record), item_id: fragment_id(record) },
           layout: false
  end

  private

  # The record being asked about, or nil with the response already sent.
  #
  # Restricted to models that actually keep the history being asked for, so the
  # type param can't be used to render an arbitrary record. `editable` adds the
  # policy check Forms::BaseController applies to editing itself: an edit trail
  # says who changed what, which is the same right the Edit button grants.
  def history_subject(concern, editable: false)
    klass = application_record_class_named(params[:type])
    return head :not_found unless klass.is_a?(Class) && klass < ApplicationRecord && klass.include?(concern)

    record = klass.find(params[:id])
    return head :forbidden if editable && !helpers.can_edit_submission?(record)

    record
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  # Unique per record within a queue page, which lists many form types at once.
  def fragment_id(record)
    "inbox-#{record.class.name}-#{record.id}"
  end
end
