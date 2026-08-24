# frozen_string_literal: true

module P2m
  class OmsUploadFinding < ApplicationRecord
    self.table_name = 'p2m_oms_upload_findings'

    belongs_to :oms_upload, class_name: 'P2m::OmsUpload', inverse_of: :findings

    validates :rule, :severity, :status, presence: true
    validates :rule, uniqueness: { scope: :oms_upload_id }
  end
end
