# frozen_string_literal: true

class CreateP2mOmsUploads < ActiveRecord::Migration[8.0]
  def change
    create_uploads
    create_files
    create_findings
  end

  private

  def create_uploads
    create_table :p2m_oms_uploads do |t|
      t.string :oms_number, null: false, limit: 9
      t.date :mailer_date, null: false
      t.string :status, null: false, default: 'staged'
      t.string :validation_status, null: false, default: 'pending'
      t.string :import_status, null: false, default: 'not_started'
      t.string :archive_status, null: false, default: 'queued'
      t.string :budget_job_id
      t.string :aims_job_id
      t.string :document_profile
      t.string :production_workflow
      t.integer :companion_file_count, null: false, default: 0
      t.integer :postal_report_count, null: false, default: 0
      t.integer :input_record_count
      t.integer :mailed_record_count
      t.integer :non_mailed_record_count
      t.string :staged_by
      t.datetime :staged_at
      t.datetime :last_seen_at
      t.datetime :validation_started_at
      t.datetime :validated_at
      t.datetime :import_started_at
      t.datetime :imported_at
      t.datetime :archived_at
      t.datetime :failed_at
      t.string :removed_by
      t.datetime :removed_at
      t.text :removal_reason
      t.text :failure_message
      t.timestamps
    end

    add_index :p2m_oms_uploads, %i[oms_number mailer_date],
              unique: true, name: 'idx_p2m_uploads_identity'
    add_index :p2m_oms_uploads, %i[status mailer_date]
  end

  def create_files
    create_table :p2m_oms_upload_files do |t|
      t.references :oms_upload, null: false, foreign_key: { to_table: :p2m_oms_uploads }
      t.string :original_filename, null: false
      t.string :category, null: false
      t.bigint :byte_size, null: false
      t.string :checksum_algorithm, null: false, default: 'SHA256'
      t.string :checksum, null: false, limit: 64
      t.datetime :source_modified_at
      t.string :archived_path
      t.datetime :archived_at
      t.string :retention_class
      t.date :retention_starts_on
      t.date :retain_until
      t.string :disposition_status, null: false, default: 'retained'
      t.datetime :disposed_at
      t.timestamps
    end

    add_index :p2m_oms_upload_files, %i[oms_upload_id original_filename],
              unique: true, name: 'idx_p2m_files_name'
  end

  def create_findings
    create_table :p2m_oms_upload_findings do |t|
      t.references :oms_upload, null: false, foreign_key: { to_table: :p2m_oms_uploads }
      t.string :rule, null: false
      t.string :severity, null: false
      t.string :status, null: false
      t.string :observed_value
      t.string :expected_value
      t.text :message
      t.timestamps
    end

    add_index :p2m_oms_upload_findings, %i[oms_upload_id rule],
              unique: true, name: 'idx_p2m_findings_rule'
  end
end
