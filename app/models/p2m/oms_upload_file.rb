# frozen_string_literal: true

module P2m
  class OmsUploadFile < GsabssBase
    self.table_name = 'p2m_oms_upload_files'

    belongs_to :oms_upload, class_name: 'P2m::OmsUpload', inverse_of: :files

    validates :original_filename, :category, :byte_size, :checksum_algorithm, :checksum, presence: true
    validates :original_filename, uniqueness: { scope: :oms_upload_id }
  end
end
