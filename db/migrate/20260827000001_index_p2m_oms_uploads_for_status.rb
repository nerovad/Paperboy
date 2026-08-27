# frozen_string_literal: true

class IndexP2mOmsUploadsForStatus < ActiveRecord::Migration[8.0]
  INDEX_NAME = 'idx_p2m_uploads_status_order'

  def up
    return if gsabss.index_name_exists?(:p2m_oms_uploads, INDEX_NAME)

    gsabss.add_index :p2m_oms_uploads, %i[mailer_date oms_number], name: INDEX_NAME
  end

  def down
    return unless gsabss.index_name_exists?(:p2m_oms_uploads, INDEX_NAME)

    gsabss.remove_index :p2m_oms_uploads, name: INDEX_NAME
  end

  private

  def gsabss
    @gsabss ||= GsabssBase.connection
  end
end
