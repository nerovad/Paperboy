# frozen_string_literal: true

class ConvertProbationStatusToStrings < ActiveRecord::Migration[8.0]
  # Phase 4 (probation): retire the legacy STATUS_MAP/integer status on
  # ProbationTransferRequest. Seeds its (previously empty) central status
  # definitions and converts the column to string keys. submitted -> in_progress.
  PROBATION_STATUSES = [
    { name: 'In Progress',      key: 'in_progress',      category: 'pending',   position: 0, is_initial: true,  is_end: false },
    { name: 'Manager Approved', key: 'manager_approved', category: 'in_review', position: 1, is_initial: false, is_end: false },
    { name: 'Sent to Security', key: 'sent_to_security', category: 'in_review', position: 2, is_initial: false, is_end: false },
    { name: 'Denied',           key: 'denied',           category: 'denied',    position: 3, is_initial: false, is_end: true }
  ].freeze

  STATUS_MAPPING = { 0 => 'in_progress', 1 => 'manager_approved', 2 => 'denied', 3 => 'sent_to_security' }.freeze

  def up
    template = FormTemplate.find_by(class_name: 'ProbationTransferRequest')
    if template
      PROBATION_STATUSES.each do |attrs|
        FormTemplateStatus.find_or_create_by!(form_template_id: template.id, key: attrs[:key]) do |s|
          s.assign_attributes(attrs.merge(auto_generated: false))
        end
      end
    end

    add_column :probation_transfer_requests, :status_str, :string, default: 'in_progress', null: false
    STATUS_MAPPING.each do |int_val, key|
      execute("UPDATE #{quote_table_name('probation_transfer_requests')} SET status_str = #{quote(key)} WHERE status = #{Integer(int_val)}")
    end
    remove_column :probation_transfer_requests, :status
    rename_column :probation_transfer_requests, :status_str, :status
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'Probation status was converted from integer to string keys; original ordinals are not recoverable.'
  end
end
