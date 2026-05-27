class ConvertStatusColumnsToStrings < ActiveRecord::Migration[8.0]
  # Phase 4: move per-form status columns from integer enum ordinals to string
  # keys. Each table's legacy integer -> canonical key mapping is explicit (not
  # derived from a model enum) so it's reviewable and stable. Renames
  # (submitted -> in_progress) and the dropped-intermediate remap
  # (step_1_approved -> step_2_pending) are baked in.
  #
  # Only the forms properly on TrackableStatus with a known integer enum are
  # included. Probation is converted separately (it needs central status rows
  # and controller changes); carpool / work_schedule are excluded (they are not
  # on TrackableStatus and need a separate fix).
  TABLE_STATUS_MAP = {
    "leave_of_absence_forms"          => { 0 => "in_progress", 1 => "step_1_pending", 2 => "approved", 3 => "denied", 4 => "cancelled" },
    "workplace_violence_forms"        => { 0 => "in_progress", 1 => "step_1_pending", 2 => "approved", 3 => "denied", 4 => "cancelled" },
    "osha_reports"                    => { 0 => "in_progress", 1 => "step_1_pending", 2 => "approved", 3 => "denied" },
    "notice_of_change_forms"          => { 0 => "in_progress", 1 => "step_1_pending", 2 => "approved", 3 => "denied", 4 => "cancelled" },
    "bike_locker_forms"               => { 0 => "in_progress", 1 => "step_1_pending", 2 => "approved", 3 => "denied" },
    "id_badge_request_forms"          => { 0 => "in_progress", 1 => "step_1_pending", 2 => "step_2_pending", 3 => "step_2_pending", 4 => "approved", 5 => "denied" },
    "safety_reports"                  => { 0 => "in_progress", 1 => "step_1_pending", 2 => "step_2_pending", 3 => "step_2_pending", 4 => "approved", 5 => "denied", 6 => "cancelled" },
    "pcard_request_forms"             => { 0 => "in_progress", 1 => "approved", 2 => "denied" },
    "critical_information_reportings" => { 0 => "in_progress", 1 => "scheduled", 2 => "resolved", 3 => "cancelled" }
  }.freeze

  def up
    TABLE_STATUS_MAP.each do |table, mapping|
      add_column table, :status_str, :string, default: "in_progress", null: false

      mapping.each do |int_val, key|
        execute("UPDATE #{quote_table_name(table)} SET status_str = #{quote(key)} WHERE status = #{Integer(int_val)}")
      end

      remove_column table, :status
      rename_column table, :status_str, :status
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Status columns were converted from integer to string keys; original ordinals are not recoverable."
  end
end
