# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class MoveP2mOmsUploadsToGsabss < ActiveRecord::Migration[8.0]
  TABLES = %i[p2m_oms_uploads p2m_oms_upload_files p2m_oms_upload_findings].freeze

  def up
    create_gsabss_tables
    copy_existing_rows
    remove_primary_tables
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'OMS upload ledger is owned by GSABSS'
  end

  private

  def create_gsabss_tables
    create_uploads unless gsabss.data_source_exists?(:p2m_oms_uploads)
    create_files unless gsabss.data_source_exists?(:p2m_oms_upload_files)
    create_findings unless gsabss.data_source_exists?(:p2m_oms_upload_findings)
  end

  def create_uploads
    gsabss.create_table :p2m_oms_uploads do |t|
      upload_columns(t)
    end
    gsabss.add_index :p2m_oms_uploads, %i[oms_number mailer_date],
                     unique: true, name: 'idx_p2m_uploads_identity'
    gsabss.add_index :p2m_oms_uploads, %i[status mailer_date]
  end

  def upload_columns(table)
    table.string :oms_number, null: false, limit: 9
    table.date :mailer_date, null: false
    status_columns(table)
    summary_columns(table)
    lifecycle_columns(table)
    table.timestamps
  end

  def status_columns(table)
    table.string :status, null: false, default: 'staged'
    table.string :validation_status, null: false, default: 'pending'
    table.string :import_status, null: false, default: 'not_started'
    table.string :archive_status, null: false, default: 'queued'
  end

  def summary_columns(table)
    %i[budget_job_id aims_job_id document_profile production_workflow staged_by removed_by].each do |column|
      table.string column
    end
    table.integer :companion_file_count, null: false, default: 0
    table.integer :postal_report_count, null: false, default: 0
    %i[input_record_count mailed_record_count non_mailed_record_count].each { |column| table.integer column }
    table.text :removal_reason
    table.text :failure_message
  end

  def lifecycle_columns(table)
    %i[
      staged_at last_seen_at validation_started_at validated_at import_started_at
      imported_at archived_at failed_at removed_at
    ].each { |column| table.datetime column }
  end

  def create_files
    gsabss.create_table :p2m_oms_upload_files do |t|
      t.references :oms_upload, null: false
      t.string :original_filename, null: false
      t.string :category, null: false
      t.bigint :byte_size, null: false
      t.string :checksum_algorithm, null: false, default: 'SHA256'
      t.string :checksum, null: false, limit: 64
      file_retention_columns(t)
      t.timestamps
    end
    gsabss.add_foreign_key :p2m_oms_upload_files, :p2m_oms_uploads, column: :oms_upload_id
    gsabss.add_index :p2m_oms_upload_files, %i[oms_upload_id original_filename],
                     unique: true, name: 'idx_p2m_files_name'
  end

  def file_retention_columns(table)
    table.datetime :source_modified_at
    table.string :archived_path
    table.datetime :archived_at
    table.string :retention_class
    table.date :retention_starts_on
    table.date :retain_until
    table.string :disposition_status, null: false, default: 'retained'
    table.datetime :disposed_at
  end

  def create_findings
    gsabss.create_table :p2m_oms_upload_findings do |t|
      t.references :oms_upload, null: false
      %i[rule severity status observed_value expected_value].each do |column|
        t.string column, null: !column.in?(%i[rule severity status])
      end
      t.text :message
      t.timestamps
    end
    gsabss.add_foreign_key :p2m_oms_upload_findings, :p2m_oms_uploads, column: :oms_upload_id
    gsabss.add_index :p2m_oms_upload_findings, %i[oms_upload_id rule],
                     unique: true, name: 'idx_p2m_findings_rule'
  end

  def copy_existing_rows
    TABLES.each { |table| copy_table(table) }
  end

  def copy_table(table)
    return unless connection.data_source_exists?(table)

    rows = connection.select_all("SELECT * FROM #{connection.quote_table_name(table)}").to_a
    rows.reject! { |row| target_row_exists?(table, row.fetch('id')) }
    return if rows.empty?

    gsabss.execute("SET IDENTITY_INSERT #{gsabss.quote_table_name(table)} ON")
    identity_enabled = true
    rows.each { |row| insert_row(table, row) }
  ensure
    gsabss.execute("SET IDENTITY_INSERT #{gsabss.quote_table_name(table)} OFF") if identity_enabled
  end

  def target_row_exists?(table, id)
    sql = "SELECT COUNT(*) FROM #{gsabss.quote_table_name(table)} WHERE #{gsabss.quote_column_name('id')} = #{gsabss.quote(id)}"
    gsabss.select_value(sql).to_i.positive?
  end

  def insert_row(table, row)
    columns = row.keys.map { |column| gsabss.quote_column_name(column) }.join(', ')
    values = row.values.map { |value| gsabss.quote(value) }.join(', ')
    gsabss.execute("INSERT INTO #{gsabss.quote_table_name(table)} (#{columns}) VALUES (#{values})")
  end

  def remove_primary_tables
    TABLES.reverse_each { |table| drop_table(table) if connection.data_source_exists?(table) }
  end

  def gsabss
    @gsabss ||= GsabssBase.connection
  end
end
# rubocop:enable Metrics/ClassLength
